//
//  WindowSwitcherController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import AppKit
import ApplicationServices
import Carbon
import Combine
import SwiftUI

struct WindowSwitcherItem: Identifiable {
    let id: String
    let appName: String
    let appIcon: NSImage
    let windowTitle: String
    let frame: CGRect
    let app: NSRunningApplication
    let processIdentifier: pid_t
    let isCurrentApp: Bool
    let isOnCurrentMonitor: Bool
}

struct BrowserTabItem: Identifiable {
    let id: String
    let browserName: String
    let browserBundleIdentifier: String
    let browserIcon: NSImage
    let windowIndex: Int
    let tabIndex: Int
    let title: String
    let url: String
}

struct BrowserWindowTabGroup: Identifiable {
    let id: String
    let windowIndex: Int
    let tabs: [BrowserTabItem]
}

struct BrowserAppTabGroup: Identifiable {
    let id: String
    let browserName: String
    let browserIcon: NSImage
    let windows: [BrowserWindowTabGroup]
}

@MainActor
final class WindowSwitcherController: ObservableObject {
    @Published private(set) var lastStatus = "Option-Tab window switcher is off."

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var forwardHotKeyRef: EventHotKeyRef?
    private var backwardHotKeyRef: EventHotKeyRef?
    private var currentAppHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var optionReleaseGlobalMonitor: Any?
    private var optionReleaseLocalMonitor: Any?
    private var optionReleaseTask: Task<Void, Never>?
    private var hotCornerTask: Task<Void, Never>?
    private var hotCornerDismissTask: Task<Void, Never>?
    private var hotCornerArmed = true
    private var hotCornerLastTriggerDate = Date.distantPast
    private var settingsObserver: NSObjectProtocol?
    private var items: [WindowSwitcherItem] = []
    private var selectedIndex = 0
    private var isShowing = false
    private var activeScope: Scope = .currentApp
    private var activeMode: OverlayMode = .windows
    private var focusedAppForSession: NSRunningApplication?
    private let presenter = WindowSwitcherOverlayPresenter()
    private let hotKeySignature = OSType(0x57535732)
    private let forwardHotKeyID = EventHotKeyID(signature: OSType(0x57535732), id: 1)
    private let backwardHotKeyID = EventHotKeyID(signature: OSType(0x57535732), id: 2)
    private let currentAppHotKeyID = EventHotKeyID(signature: OSType(0x57535732), id: 3)

    func start() {
        WindowSwitcherSettingsStore.seedDefaultsIfNeeded()
        observeSettings()
        reloadEventTap()
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let forwardHotKeyRef {
            UnregisterEventHotKey(forwardHotKeyRef)
        }
        if let backwardHotKeyRef {
            UnregisterEventHotKey(backwardHotKeyRef)
        }
        if let currentAppHotKeyRef {
            UnregisterEventHotKey(currentAppHotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let optionReleaseGlobalMonitor {
            NSEvent.removeMonitor(optionReleaseGlobalMonitor)
        }
        if let optionReleaseLocalMonitor {
            NSEvent.removeMonitor(optionReleaseLocalMonitor)
        }
        optionReleaseTask?.cancel()
        hotCornerTask?.cancel()
        hotCornerDismissTask?.cancel()
        ModifierKeySafety.releaseAfterShortcutEnds()
    }

    private func observeSettings() {
        guard settingsObserver == nil else { return }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: WindowSwitcherSettingsStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadEventTap()
            }
        }
    }

    private func reloadEventTap() {
        unregisterEventTap()

        guard WindowSwitcherSettingsStore.enabled else {
            lastStatus = "Option-Tab window switcher is off."
            return
        }

        guard AXIsProcessTrusted() else {
            lastStatus = "Accessibility permission is required."
            return
        }

        registerHotKeys()
        registerOptionReleaseMonitors()
        startHotCornerWatcherIfNeeded()
    }

    private func registerHotKeys() {
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install Option-Tab handler."
            return
        }

        if forwardHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_Tab),
                UInt32(optionKey),
                forwardHotKeyID,
                GetApplicationEventTarget(),
                0,
                &forwardHotKeyRef
            )
            logHotKeyStatus("Option-Tab", status)
        }

        if backwardHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_Tab),
                UInt32(optionKey | shiftKey),
                backwardHotKeyID,
                GetApplicationEventTarget(),
                0,
                &backwardHotKeyRef
            )
            logHotKeyStatus("Option-Shift-Tab", status)
        }

        if currentAppHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_Grave),
                UInt32(optionKey),
                currentAppHotKeyID,
                GetApplicationEventTarget(),
                0,
                &currentAppHotKeyRef
            )
            logHotKeyStatus("Option-`", status)
        }
    }

    private func logHotKeyStatus(_ shortcut: String, _ status: OSStatus) {
        if status == noErr {
            lastStatus = "\(shortcut) is ready."
            log("\(shortcut) registered")
        } else {
            lastStatus = "\(shortcut) is already used by another app."
            log("\(shortcut) registration failed \(status)")
        }
    }

    private func ensureEventHandlerInstalled() -> Bool {
        guard eventHandlerRef == nil else { return true }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.signature == OSType(0x57535732) else {
                    return noErr
                }

                let controller = Unmanaged<WindowSwitcherController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.handleHotKey(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        return status == noErr
    }

    private func handleHotKey(id: UInt32) {
        switch id {
        case forwardHotKeyID.id:
            log("Option-Tab pressed")
            cycleWindows(direction: .forward, scope: .currentApp, closeMode: .optionRelease)
        case backwardHotKeyID.id:
            log("Option-Shift-Tab pressed")
            cycleWindows(direction: .backward, scope: .currentApp, closeMode: .optionRelease)
        case currentAppHotKeyID.id:
            log("Option-` pressed")
            cycleWindows(direction: .forward, scope: .currentApp, closeMode: .optionRelease)
        default:
            break
        }
    }

    private func unregisterHotKeys() {
        if let forwardHotKeyRef {
            UnregisterEventHotKey(forwardHotKeyRef)
            self.forwardHotKeyRef = nil
        }
        if let backwardHotKeyRef {
            UnregisterEventHotKey(backwardHotKeyRef)
            self.backwardHotKeyRef = nil
        }
        if let currentAppHotKeyRef {
            UnregisterEventHotKey(currentAppHotKeyRef)
            self.currentAppHotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func registerOptionReleaseMonitors() {
        guard optionReleaseGlobalMonitor == nil, optionReleaseLocalMonitor == nil else { return }

        optionReleaseGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.handleFlagsChanged(event.modifierFlags)
            }
        }

        optionReleaseLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event.modifierFlags)
            }
            return event
        }
    }

    private func unregisterOptionReleaseMonitors() {
        if let optionReleaseGlobalMonitor {
            NSEvent.removeMonitor(optionReleaseGlobalMonitor)
            self.optionReleaseGlobalMonitor = nil
        }
        if let optionReleaseLocalMonitor {
            NSEvent.removeMonitor(optionReleaseLocalMonitor)
            self.optionReleaseLocalMonitor = nil
        }
    }

    private func handleFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        guard isShowing, !flags.contains(.option) else { return }
        commitSelection()
    }

    private func registerEventTap() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }

            let controller = Unmanaged<WindowSwitcherController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if type == .flagsChanged {
                if controller.isShowing, !event.flags.contains(.maskAlternate) {
                    Task { @MainActor in
                        controller.commitSelection()
                    }
                    return nil
                }

                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            if controller.isForwardWindowSwitchEvent(event) {
                Task { @MainActor in
                    controller.cycleWindows(direction: .forward, scope: .currentApp, closeMode: .optionRelease)
                }
                return nil
            }

            if controller.isBackwardWindowSwitchEvent(event) {
                Task { @MainActor in
                    controller.cycleWindows(direction: .backward, scope: .currentApp, closeMode: .optionRelease)
                }
                return nil
            }

            if controller.isCurrentAppWindowSwitchEvent(event) {
                Task { @MainActor in
                    controller.cycleWindows(direction: .forward, scope: .currentApp, closeMode: .optionRelease)
                }
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            lastStatus = "Could not install Option-Tab handler."
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        lastStatus = "Option-Tab is ready."
    }

    private func unregisterEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        presenter.hide()
        isShowing = false
        items = []
        activeScope = .currentApp
        focusedAppForSession = nil
        optionReleaseTask?.cancel()
        optionReleaseTask = nil
        hotCornerTask?.cancel()
        hotCornerTask = nil
        hotCornerDismissTask?.cancel()
        hotCornerDismissTask = nil
        hotCornerArmed = true
        unregisterHotKeys()
        unregisterOptionReleaseMonitors()
        ModifierKeySafety.releaseAfterShortcutEnds()
    }

    private enum Direction {
        case forward
        case backward
    }

    private enum Scope {
        case all
        case currentApp

        var logName: String {
            switch self {
            case .all:
                return "all-app"
            case .currentApp:
                return "current-app"
            }
        }
    }

    private enum OverlayMode {
        case windows
        case browserTabs
    }

    private enum CloseMode {
        case optionRelease
        case mouseClick
    }

    private func cycleWindows(direction: Direction, scope: Scope, closeMode: CloseMode) {
        guard AXIsProcessTrusted() else {
            lastStatus = "Accessibility permission is required."
            return
        }

        if !isShowing {
            focusedAppForSession = NSWorkspace.shared.frontmostApplication
            activeScope = scope
            items = collectWindowItems(scope: scope, focusedApp: focusedAppForSession)
            selectedIndex = 0

            if direction == .backward, !items.isEmpty {
                selectedIndex = max(items.count - 1, 0)
            }
        } else if !items.isEmpty {
            switch direction {
            case .forward:
                selectedIndex = (selectedIndex + 1) % items.count
            case .backward:
                selectedIndex = (selectedIndex - 1 + items.count) % items.count
            }
        }

        guard !items.isEmpty else {
            lastStatus = "No visible windows found."
            log("no visible windows found")
            presenter.hide()
            isShowing = false
            activeScope = .currentApp
            focusedAppForSession = nil
            return
        }

        isShowing = true
        activeMode = .windows
        lastStatus = "\(items.count) windows available."
        log("showing \(items.count) \(activeScope.logName) windows selected \(selectedIndex)")
        presenter.show(
            items: items,
            selectedIndex: selectedIndex,
            showThumbnails: WindowSwitcherSettingsStore.showThumbnails,
            isShowingAllApps: activeScope == .all,
            canShowBrowserTabs: canShowBrowserTabs
        ) { [weak self] in
            self?.expandToAllWindows()
        } onShowBrowserTabs: { [weak self] in
            self?.showAllBrowserTabs()
        } onSelectItem: { [weak self] itemID in
            self?.commitSelection(itemID: itemID)
        }

        if closeMode == .optionRelease {
            hotCornerDismissTask?.cancel()
            hotCornerDismissTask = nil
            watchForOptionRelease()
        } else {
            optionReleaseTask?.cancel()
            optionReleaseTask = nil
            watchForHotCornerDismiss()
        }
    }

    private func commitSelection() {
        commitSelection(itemID: nil)
    }

    private func commitSelection(itemID: String?) {
        if let itemID, let index = items.firstIndex(where: { $0.id == itemID }) {
            selectedIndex = index
        }

        defer {
            presenter.hide()
            isShowing = false
            items = []
            selectedIndex = 0
            activeScope = .currentApp
            activeMode = .windows
            focusedAppForSession = nil
            optionReleaseTask?.cancel()
            optionReleaseTask = nil
            hotCornerDismissTask?.cancel()
            hotCornerDismissTask = nil
            ModifierKeySafety.releaseAfterShortcutEnds()
        }

        guard items.indices.contains(selectedIndex) else { return }

        let item = items[selectedIndex]
        if WindowSwitcherSettingsStore.moveCursorToSelectedMonitor {
            moveCursor(to: item.frame)
        }

        item.app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if let window = accessibilityWindow(for: item) {
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        lastStatus = "Focused \(item.appName)."
        log("focused \(item.appName) \(item.windowTitle)")
    }

    private func dismissOverlayWithoutSelection() {
        presenter.hide()
        isShowing = false
        items = []
        selectedIndex = 0
        activeScope = .currentApp
        activeMode = .windows
        focusedAppForSession = nil
        optionReleaseTask?.cancel()
        optionReleaseTask = nil
        hotCornerDismissTask?.cancel()
        hotCornerDismissTask = nil
        ModifierKeySafety.releaseAfterShortcutEnds()
        lastStatus = "Switcher dismissed."
        log("hot corner switcher dismissed after timeout")
    }

    private func expandToAllWindows() {
        guard isShowing else { return }

        activeScope = .all
        let selectedItemID = items.indices.contains(selectedIndex) ? items[selectedIndex].id : nil
        items = collectWindowItems(scope: .all, focusedApp: focusedAppForSession)

        if let selectedItemID,
           let expandedIndex = items.firstIndex(where: { $0.id == selectedItemID }) {
            selectedIndex = expandedIndex
        } else {
            selectedIndex = 0
        }

        guard !items.isEmpty else { return }

        lastStatus = "\(items.count) windows available."
        log("expanded to all apps \(items.count) windows selected \(selectedIndex)")
        presenter.show(
            items: items,
            selectedIndex: selectedIndex,
            showThumbnails: WindowSwitcherSettingsStore.showThumbnails,
            isShowingAllApps: true,
            canShowBrowserTabs: canShowBrowserTabs
        ) { [weak self] in
            self?.expandToAllWindows()
        } onShowBrowserTabs: { [weak self] in
            self?.showAllBrowserTabs()
        } onSelectItem: { [weak self] itemID in
            self?.commitSelection(itemID: itemID)
        }
    }

    private func startHotCornerWatcherIfNeeded() {
        hotCornerTask?.cancel()
        hotCornerTask = nil
        hotCornerArmed = true

        guard WindowSwitcherSettingsStore.bottomRightHotCorner else { return }

        hotCornerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 90_000_000)
                self?.checkBottomRightHotCorner()
            }
        }
    }

    private func checkBottomRightHotCorner() {
        guard WindowSwitcherSettingsStore.enabled,
              WindowSwitcherSettingsStore.bottomRightHotCorner,
              !isShowing else { return }

        let mousePoint = NSEvent.mouseLocation
        guard let screen = screen(containingOrNearest: mousePoint) else { return }
        let frame = screen.frame
        let threshold: CGFloat = 4
        let inCorner = mousePoint.x >= frame.maxX - threshold
            && mousePoint.x <= frame.maxX + threshold
            && mousePoint.y <= frame.minY + threshold
            && mousePoint.y >= frame.minY - threshold

        if !inCorner {
            hotCornerArmed = true
            return
        }

        guard hotCornerArmed,
              Date().timeIntervalSince(hotCornerLastTriggerDate) > 1.0 else { return }

        hotCornerArmed = false
        hotCornerLastTriggerDate = Date()
        log("bottom-right hot corner triggered")
        cycleWindows(direction: .forward, scope: .currentApp, closeMode: .mouseClick)
    }

    private func watchForHotCornerDismiss() {
        hotCornerDismissTask?.cancel()
        hotCornerDismissTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var mouseAwayStartedAt: Date?
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard self.isShowing, self.activeMode == .windows else { break }

                if self.presenter.isMouseInsideOverlay {
                    mouseAwayStartedAt = nil
                    continue
                }

                if mouseAwayStartedAt == nil {
                    mouseAwayStartedAt = Date()
                }

                if let mouseAwayStartedAt,
                   Date().timeIntervalSince(mouseAwayStartedAt) >= 3.0 {
                    self.dismissOverlayWithoutSelection()
                    break
                }
            }
        }
    }

    private func watchForOptionRelease() {
        guard optionReleaseTask == nil else { return }

        optionReleaseTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self, self.isShowing else { break }
                guard self.activeMode == .windows else { continue }

                let flags = CGEventSource.flagsState(.combinedSessionState)
                if !flags.contains(.maskAlternate) {
                    self.commitSelection()
                    break
                }
            }
        }
    }

    private var canShowBrowserTabs: Bool {
        if let focusedAppForSession,
           Self.supportedBrowserBundleIdentifiers.contains(focusedAppForSession.bundleIdentifier ?? "") {
            return true
        }

        guard items.indices.contains(selectedIndex) else { return false }
        return Self.supportedBrowserBundleIdentifiers.contains(items[selectedIndex].app.bundleIdentifier ?? "")
    }

    private static let supportedBrowserBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.microsoft.edgemac"
    ]

    private func showAllBrowserTabs() {
        let groups = collectBrowserTabGroups()
        guard !groups.isEmpty else {
            lastStatus = "No browser tabs found."
            log("no browser tabs found")
            return
        }

        activeMode = .browserTabs
        optionReleaseTask?.cancel()
        optionReleaseTask = nil
        lastStatus = "Showing browser tabs."
        log("showing all browser tabs \(groups.reduce(0) { total, app in total + app.windows.reduce(0) { $0 + $1.tabs.count } }) tabs")
        presenter.showBrowserTabs(groups: groups) { [weak self] item in
            self?.activateBrowserTab(item)
        }
    }

    private func collectBrowserTabGroups() -> [BrowserAppTabGroup] {
        browserDefinitions.compactMap { definition -> BrowserAppTabGroup? in
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: definition.bundleIdentifier).first else {
                return nil
            }

            let windows = browserWindows(for: definition, app: app)
            guard !windows.isEmpty else { return nil }

            return BrowserAppTabGroup(
                id: definition.bundleIdentifier,
                browserName: definition.name,
                browserIcon: app.icon ?? NSWorkspace.shared.icon(forFileType: "app"),
                windows: windows
            )
        }
    }

    private struct BrowserDefinition {
        let name: String
        let bundleIdentifier: String
        let applicationName: String
    }

    private var browserDefinitions: [BrowserDefinition] {
        [
            BrowserDefinition(name: "Chrome", bundleIdentifier: "com.google.Chrome", applicationName: "Google Chrome"),
            BrowserDefinition(name: "Safari", bundleIdentifier: "com.apple.Safari", applicationName: "Safari"),
            BrowserDefinition(name: "Edge", bundleIdentifier: "com.microsoft.edgemac", applicationName: "Microsoft Edge")
        ]
    }

    private func browserWindows(for definition: BrowserDefinition, app: NSRunningApplication) -> [BrowserWindowTabGroup] {
        let scriptSource = browserTabScript(for: definition.applicationName)
        guard let output = runAppleScript(scriptSource) else { return [] }

        var windows: [BrowserWindowTabGroup] = []
        var currentWindowIndex: Int?
        var currentTabs: [BrowserTabItem] = []
        let browserIcon = app.icon ?? NSWorkspace.shared.icon(forFileType: "app")

        func flushWindow() {
            guard let windowIndex = currentWindowIndex, !currentTabs.isEmpty else { return }
            windows.append(
                BrowserWindowTabGroup(
                    id: "\(definition.bundleIdentifier)-window-\(windowIndex)",
                    windowIndex: windowIndex,
                    tabs: currentTabs
                )
            )
            currentTabs = []
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let type = parts.first else { continue }

            if type == "WINDOW", parts.count >= 2 {
                flushWindow()
                currentWindowIndex = Int(parts[1])
            } else if type == "TAB", parts.count >= 4, let windowIndex = currentWindowIndex {
                let tabIndex = Int(parts[1]) ?? 1
                let title = parts[2].isEmpty ? "Untitled Tab" : parts[2]
                let url = parts[3]
                currentTabs.append(
                    BrowserTabItem(
                        id: "\(definition.bundleIdentifier)-\(windowIndex)-\(tabIndex)-\(title)-\(url)",
                        browserName: definition.name,
                        browserBundleIdentifier: definition.bundleIdentifier,
                        browserIcon: browserIcon,
                        windowIndex: windowIndex,
                        tabIndex: tabIndex,
                        title: title,
                        url: url
                    )
                )
            }
        }

        flushWindow()
        return windows
    }

    private func browserTabScript(for applicationName: String) -> String {
        """
        tell application "\(applicationName)"
          set output to ""
          repeat with wi from 1 to count of windows
            set output to output & "WINDOW\t" & wi & linefeed
            repeat with ti from 1 to count of tabs of window wi
              set tabTitle to title of tab ti of window wi
              set tabURL to URL of tab ti of window wi
              set output to output & "TAB\t" & ti & "\t" & tabTitle & "\t" & tabURL & linefeed
            end repeat
          end repeat
          return output
        end tell
        """
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            log("browser tabs apple script failed \(error)")
        }
        return result?.stringValue
    }

    private func activateBrowserTab(_ item: BrowserTabItem) {
        let definition = browserDefinitions.first { $0.bundleIdentifier == item.browserBundleIdentifier }
        guard let definition else { return }

        let script = """
        tell application "\(definition.applicationName)"
          activate
          set active tab index of window \(item.windowIndex) to \(item.tabIndex)
          set index of window \(item.windowIndex) to 1
        end tell
        """
        _ = runAppleScript(script)
        presenter.hide()
        isShowing = false
        items = []
        selectedIndex = 0
        activeScope = .currentApp
        activeMode = .windows
        focusedAppForSession = nil
        ModifierKeySafety.releaseAfterShortcutEnds()
        log("focused browser tab \(item.browserName) window \(item.windowIndex) tab \(item.tabIndex) \(item.title)")
    }

    private func collectWindowItems(scope: Scope, focusedApp: NSRunningApplication?) -> [WindowSwitcherItem] {
        let currentMousePoint = NSEvent.mouseLocation
        let currentScreen = screen(containing: currentMousePoint) ?? NSScreen.main
        let runningAppsByPID = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) })

        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let unsortedItems = windows.compactMap { info -> WindowSwitcherItem? in
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }

            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let app = runningAppsByPID[pid] else {
                return nil
            }

            guard app.activationPolicy == .regular else { return nil }
            guard !WindowSwitcherSettingsStore.excludeFinder || app.bundleIdentifier != "com.apple.finder" else { return nil }
            guard !WindowSwitcherSettingsStore.excludeHiddenApps || !app.isHidden else { return nil }
            guard scope == .all || app.processIdentifier == focusedApp?.processIdentifier else { return nil }

            guard let boundsObject = info[kCGWindowBounds as String] else { return nil }
            let boundsDictionary = boundsObject as! CFDictionary
            var frame = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDictionary, &frame) else { return nil }
            guard frame.width > 80, frame.height > 60 else { return nil }

            let appName = app.localizedName ?? (info[kCGWindowOwnerName as String] as? String) ?? "Unknown App"
            let title = (info[kCGWindowName as String] as? String) ?? ""
            let isCurrentApp = app.processIdentifier == focusedApp?.processIdentifier
            let isOnCurrentMonitor = currentScreen.map { $0.frame.intersects(frame) } ?? false

            return WindowSwitcherItem(
                id: "\(pid)-\((info[kCGWindowNumber as String] as? Int) ?? 0)",
                appName: appName,
                appIcon: app.icon ?? NSWorkspace.shared.icon(forFileType: "app"),
                windowTitle: title.isEmpty ? "Untitled Window" : title,
                frame: frame,
                app: app,
                processIdentifier: pid,
                isCurrentApp: isCurrentApp,
                isOnCurrentMonitor: isOnCurrentMonitor
            )
        }

        return unsortedItems.sorted { lhs, rhs in
            if lhs.isCurrentApp != rhs.isCurrentApp {
                return lhs.isCurrentApp
            }

            if WindowSwitcherSettingsStore.currentMonitorFirst, lhs.isOnCurrentMonitor != rhs.isOnCurrentMonitor {
                return lhs.isOnCurrentMonitor
            }

            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    private func accessibilityWindow(for item: WindowSwitcherItem) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(item.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.first { window in
            let title = stringAttribute(kAXTitleAttribute, for: window)
            if title == item.windowTitle {
                return true
            }
            guard let frame = frame(for: window) else { return false }
            return abs(frame.origin.x - item.frame.origin.x) < 8
                && abs(frame.width - item.frame.width) < 8
                && abs(frame.height - item.frame.height) < 8
        } ?? windows.first
    }

    private func windows(for app: NSRunningApplication, focusedApp: NSRunningApplication?, currentScreen: NSScreen?) -> [WindowSwitcherItem] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }

        let appName = app.localizedName ?? "Unknown App"
        let appIcon = app.icon ?? NSWorkspace.shared.icon(forFileType: "app")

        return windows.compactMap { window in
            guard let frame = frame(for: window), frame.width > 80, frame.height > 60 else { return nil }

            let minimized = boolAttribute(kAXMinimizedAttribute, for: window)
            guard WindowSwitcherSettingsStore.includeMinimized || !minimized else { return nil }

            let title = stringAttribute(kAXTitleAttribute, for: window)
            let role = stringAttribute(kAXRoleAttribute, for: window)
            guard role.isEmpty || role == kAXWindowRole as String else { return nil }

            let windowID = "\(app.processIdentifier)-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(title)"
            let isCurrentApp = app.processIdentifier == focusedApp?.processIdentifier
            let isOnCurrentMonitor = currentScreen.map { $0.frame.intersects(frame) } ?? false

            return WindowSwitcherItem(
                id: windowID,
                appName: appName,
                appIcon: appIcon,
                windowTitle: title.isEmpty ? "Untitled Window" : title,
                frame: frame,
                app: app,
                processIdentifier: app.processIdentifier,
                isCurrentApp: isCurrentApp,
                isOnCurrentMonitor: isOnCurrentMonitor
            )
        }
    }

    private func frame(for window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let position = positionValue, let size = sizeValue else {
            return nil
        }

        var point = CGPoint.zero
        var cgSize = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &cgSize) else {
            return nil
        }

        return CGRect(origin: point, size: cgSize)
    }

    private func boolAttribute(_ attribute: String, for window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success else {
            return false
        }

        return (value as? Bool) ?? false
    }

    private func stringAttribute(_ attribute: String, for window: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success else {
            return ""
        }

        return (value as? String) ?? ""
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func screen(containingOrNearest point: CGPoint) -> NSScreen? {
        if let screen = screen(containing: point) {
            return screen
        }

        return NSScreen.screens.min { lhs, rhs in
            distance(from: point, to: lhs.frame) < distance(from: point, to: rhs.frame)
        }
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private func moveCursor(to frame: CGRect) {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        CGWarpMouseCursorPosition(point)
    }

    private func isForwardWindowSwitchEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Tab)
            && event.flags.contains(.maskAlternate)
            && !event.flags.contains(.maskShift)
    }

    private func isBackwardWindowSwitchEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Tab)
            && event.flags.contains(.maskAlternate)
            && event.flags.contains(.maskShift)
    }

    private func isCurrentAppWindowSwitchEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_Grave)
            && event.flags.contains(.maskAlternate)
    }

    private func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-window-switcher.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

private final class WindowSwitcherOverlayPresenter {
    private var panel: WindowSwitcherPanel?

    @MainActor
    func show(
        items: [WindowSwitcherItem],
        selectedIndex: Int,
        showThumbnails: Bool,
        isShowingAllApps: Bool,
        canShowBrowserTabs: Bool,
        onShowAll: @escaping () -> Void,
        onShowBrowserTabs: @escaping () -> Void,
        onSelectItem: @escaping (String) -> Void
    ) {
        let overlay = WindowSwitcherOverlay(
            items: items,
            selectedIndex: selectedIndex,
            showThumbnails: showThumbnails,
            isShowingAllApps: isShowingAllApps,
            canShowBrowserTabs: canShowBrowserTabs,
            onShowAll: onShowAll,
            onShowBrowserTabs: onShowBrowserTabs,
            onSelectItem: onSelectItem
        )
        show(rootView: overlay, size: NSSize(width: 680, height: 190))
    }

    @MainActor
    func showBrowserTabs(groups: [BrowserAppTabGroup], onSelectTab: @escaping (BrowserTabItem) -> Void) {
        let overlay = BrowserTabsOverlay(groups: groups, onSelectTab: onSelectTab)
        show(rootView: overlay, size: NSSize(width: 860, height: 620))
    }

    @MainActor
    private func show<Content: View>(rootView: Content, size: NSSize) {
        if let panel {
            panel.setContentSize(size)
            center(panel)
            panel.contentView = NSHostingView(rootView: rootView)
            panel.orderFrontRegardless()
            return
        }

        let panel = WindowSwitcherPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .utilityWindow
        panel.contentView = NSHostingView(rootView: rootView)
        center(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    @MainActor
    func hide() {
        panel?.orderOut(nil)
    }

    @MainActor
    var isMouseInsideOverlay: Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.contains(NSEvent.mouseLocation)
    }

    @MainActor
    private func center(_ panel: NSPanel) {
        let screenFrame = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? .zero
        panel.setFrameOrigin(
            CGPoint(
                x: screenFrame.midX - panel.frame.width / 2,
                y: screenFrame.midY - panel.frame.height / 2
            )
        )
    }
}

private final class WindowSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct WindowSwitcherOverlay: View {
    let items: [WindowSwitcherItem]
    let selectedIndex: Int
    let showThumbnails: Bool
    let isShowingAllApps: Bool
    let canShowBrowserTabs: Bool
    let onShowAll: () -> Void
    let onShowBrowserTabs: () -> Void
    let onSelectItem: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isShowingAllApps ? "All Windows" : "Current App Windows")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                if !isShowingAllApps {
                    Button("All", action: onShowAll)
                        .buttonStyle(WindowSwitcherAllButtonStyle())
                }

                if canShowBrowserTabs {
                    Button("All Tabs", action: onShowBrowserTabs)
                        .buttonStyle(WindowSwitcherAllButtonStyle())
                }

                Spacer()

                Text("Click a card or release Option")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: items.count > 5) {
                    HStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            Button {
                                onSelectItem(item.id)
                            } label: {
                                WindowSwitcherCard(item: item, isSelected: index == selectedIndex, showThumbnails: showThumbnails)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
                .onChange(of: selectedIndex) { newIndex in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 680, height: 190)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.80))
        )
    }
}

private struct WindowSwitcherCard: View {
    let item: WindowSwitcherItem
    let isSelected: Bool
    let showThumbnails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(showThumbnails ? 0.16 : 0.10))

                Image(nsImage: item.appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 38, height: 38)
                    .opacity(showThumbnails ? 0.72 : 1)
            }
            .frame(height: 62)

            Text(item.appName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(item.windowTitle)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .frame(height: 28, alignment: .topLeading)
        }
        .padding(10)
        .frame(width: 126, height: 132)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.58) : Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct BrowserTabsOverlay: View {
    let groups: [BrowserAppTabGroup]
    let onSelectTab: (BrowserTabItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Browser Tabs")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .padding(.top, 2)

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(groups) { appGroup in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 9) {
                                Image(nsImage: appGroup.browserIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)

                                Text(appGroup.browserName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            ForEach(appGroup.windows) { windowGroup in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Window \(windowGroup.windowIndex)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.70))

                                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                        ForEach(windowGroup.tabs) { tab in
                                            Button {
                                                onSelectTab(tab)
                                            } label: {
                                                BrowserTabCard(tab: tab)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 10)
            }
        }
        .padding(24)
        .frame(width: 860, height: 620)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.84))
        )
    }
}

private struct BrowserTabCard: View {
    let tab: BrowserTabItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(nsImage: tab.browserIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text(tab.browserName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }

            Text(tab.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(height: 30, alignment: .topLeading)

            Text(tab.url)
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct WindowSwitcherAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? Color.white.opacity(0.26) : Color.white.opacity(0.16))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
