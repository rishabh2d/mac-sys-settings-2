//
//  AudioTabJumpController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/24/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class AudioTabJumpController: ObservableObject {
    static let shared = AudioTabJumpController()

    private struct AudioTabMatch {
        let id: Int
        let app: NSRunningApplication
        let window: AXUIElement
        let tabButton: AXUIElement
        let title: String
        let windowTitle: String

        var choice: AudioTabChoice {
            AudioTabChoice(
                id: id,
                number: id + 1,
                title: title,
                browserName: app.localizedName ?? "Browser",
                windowTitle: cleanTitle(windowTitle)
            )
        }

        private func cleanTitle(_ title: String) -> String {
            title
                .replacingOccurrences(of: " - Google Chrome", with: "")
                .replacingOccurrences(of: " - Safari", with: "")
        }
    }

    @Published private(set) var lastStatus = "Ready"

    private let choicePresenter = AudioTabChoicePresenter()
    private let hudPresenter = CenteredHUDPresenter()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var observer: NSObjectProtocol?
    private var lastJumpAt = Date.distantPast
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4155444A), id: 1)
    private let browserBundleIDs = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview"
    ]

    func start() {
        observeChanges()
        registerHotKey()
        registerKeyMonitors()
    }

    func jumpToPlayingTab() {
        guard AXIsProcessTrusted() else {
            lastStatus = "Allow Accessibility"
            return
        }

        let matches = audioTabs()

        if matches.count == 1, let match = matches.first {
            hudPresenter.hide()
            focus(match)
            return
        }

        if matches.count > 1 {
            hudPresenter.hide()
            choicePresenter.show(
                choices: matches.map(\.choice),
                onSelect: { [weak self] choice in
                    guard let match = matches.first(where: { $0.id == choice.id }) else { return }
                    self?.focus(match)
                },
                onCancel: { [weak self] in
                    self?.lastStatus = "Audio tab chooser closed"
                }
            )
            lastStatus = "Choose audio tab"
            return
        }

        hudPresenter.hide()
        lastStatus = "No audio tab found"
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observeChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: AudioTabJumpStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadHotKey()
            }
        }
    }

    private func reloadHotKey() {
        unregisterHotKey()
        unregisterKeyMonitors()
        unregisterEventTap()
        registerHotKey()
        registerKeyMonitors()
        registerEventTap()
    }

    private func registerHotKey() {
        guard AudioTabJumpStore.isEnabled, hotKeyRef == nil else { return }
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install shortcut"
            return
        }

        let shortcut = AudioTabJumpStore.shortcut
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        lastStatus = status == noErr ? "\(shortcut.displayText) ready" : "\(shortcut.displayText) could not register"
        registerEventTap()
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func ensureEventHandlerInstalled() -> Bool {
        if eventHandlerRef != nil { return true }

        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == OSType(0x4155444A),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<AudioTabJumpController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.triggerJumpFromShortcut()
                }

                return noErr
            },
            1,
            &eventTypes,
            selfPointer,
            &eventHandlerRef
        )

        return status == noErr
    }

    private func registerKeyMonitors() {
        guard AudioTabJumpStore.isEnabled, globalKeyMonitor == nil, localKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.handlePotentialShortcut(event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let controller = self else { return event }
            var handled = false
            Task { @MainActor in
                handled = controller.handlePotentialShortcut(event)
            }
            return handled ? nil : event
        }
    }

    private func unregisterKeyMonitors() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func registerEventTap() {
        guard AudioTabJumpStore.isEnabled, eventTap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<AudioTabJumpController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            Task { @MainActor in
                controller.handlePotentialShortcut(keyCode: keyCode, flags: flags)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: selfPointer
        ) else {
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func unregisterEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
    }

    @discardableResult
    private func handlePotentialShortcut(_ event: NSEvent) -> Bool {
        guard AudioTabJumpStore.isEnabled, shortcutMatches(event) else { return false }
        triggerJumpFromShortcut()
        return true
    }

    private func shortcutMatches(_ event: NSEvent) -> Bool {
        let shortcut = AudioTabJumpStore.shortcut
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        let hasControl = flags.contains(.control)
        let hasOption = flags.contains(.option)
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let expectedControl = shortcut.carbonModifiers & UInt32(controlKey) != 0
        let expectedOption = shortcut.carbonModifiers & UInt32(optionKey) != 0
        let expectedCommand = shortcut.carbonModifiers & UInt32(cmdKey) != 0
        let expectedShift = shortcut.carbonModifiers & UInt32(shiftKey) != 0

        return UInt32(event.keyCode) == shortcut.keyCode
            && hasControl == expectedControl
            && hasOption == expectedOption
            && hasCommand == expectedCommand
            && hasShift == expectedShift
    }

    private func handlePotentialShortcut(keyCode: UInt32, flags: CGEventFlags) {
        guard AudioTabJumpStore.isEnabled, shortcutMatches(keyCode: keyCode, flags: flags) else { return }
        triggerJumpFromShortcut()
    }

    private func shortcutMatches(keyCode: UInt32, flags: CGEventFlags) -> Bool {
        let shortcut = AudioTabJumpStore.shortcut
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let expectedControl = shortcut.carbonModifiers & UInt32(controlKey) != 0
        let expectedOption = shortcut.carbonModifiers & UInt32(optionKey) != 0
        let expectedCommand = shortcut.carbonModifiers & UInt32(cmdKey) != 0
        let expectedShift = shortcut.carbonModifiers & UInt32(shiftKey) != 0

        return keyCode == shortcut.keyCode
            && hasControl == expectedControl
            && hasOption == expectedOption
            && hasCommand == expectedCommand
            && hasShift == expectedShift
    }

    private func triggerJumpFromShortcut() {
        let now = Date()
        guard now.timeIntervalSince(lastJumpAt) > 0.25 else { return }
        lastJumpAt = now
        lastStatus = "Searching audio tabs"
        hudPresenter.show(.searching)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            self?.jumpToPlayingTab()
        }
    }

    private func focus(_ match: AudioTabMatch) {
        setBoolAttribute(kAXMinimizedAttribute, on: match.window, value: false)
        match.app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(match.window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(match.window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(match.window, kAXRaiseAction as CFString)
        AXUIElementPerformAction(match.tabButton, kAXPressAction as CFString)
        lastStatus = "Opened \(match.title)"
    }

    private func audioTabs() -> [AudioTabMatch] {
        var matches: [AudioTabMatch] = []

        for bundleID in browserBundleIDs {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                for window in windows(of: appElement) {
                    let windowTitle = stringAttribute(kAXTitleAttribute, on: window) ?? (app.localizedName ?? "Browser")
                    let tabButtons = audioTabButtons(in: window, depth: 0)
                    for tabButton in tabButtons {
                        matches.append(
                            AudioTabMatch(
                                id: matches.count,
                                app: app,
                                window: window,
                                tabButton: tabButton,
                                title: audioTabTitle(tabButton),
                                windowTitle: windowTitle
                            )
                        )
                    }
                }
            }
        }

        return matches
    }

    private func audioTabButtons(in element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth < 12 else { return [] }

        var matches: [AXUIElement] = []

        if role(of: element) == kAXRadioButtonRole as String,
           elementLooksLikePlayingTab(element) {
            matches.append(element)
        }

        for child in children(of: element) {
            matches.append(contentsOf: audioTabButtons(in: child, depth: depth + 1))
        }

        return matches
    }

    private func elementLooksLikePlayingTab(_ element: AXUIElement) -> Bool {
        let text = [
            stringAttribute(kAXDescriptionAttribute, on: element),
            stringAttribute(kAXTitleAttribute, on: element),
            stringAttribute(kAXHelpAttribute, on: element),
            stringAttribute(kAXValueAttribute, on: element)
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        return text.contains("audio playing")
            || text.contains("playing audio")
            || text.contains("tab is playing")
            || (text.contains("audio") && text.contains("playing"))
    }

    private func role(of element: AXUIElement) -> String? {
        stringAttribute(kAXRoleAttribute, on: element)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }

        return children
    }

    private func windows(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }

        return windows
    }

    private func setBoolAttribute(_ attribute: String, on element: AXUIElement, value: Bool) {
        AXUIElementSetAttributeValue(element, attribute as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else {
            return nil
        }

        return value as? String
    }

    private func audioTabTitle(_ element: AXUIElement) -> String {
        let rawTitle = [
            stringAttribute(kAXDescriptionAttribute, on: element),
            stringAttribute(kAXTitleAttribute, on: element),
            stringAttribute(kAXHelpAttribute, on: element)
        ]
        .compactMap { $0 }
        .first { !$0.isEmpty } ?? "Playing audio"

        return rawTitle
            .replacingOccurrences(of: " - Audio playing", with: "")
            .replacingOccurrences(of: " - audio playing", with: "")
            .replacingOccurrences(of: #"\s+-\s+Memory usage\s+-\s+.+$"#, with: "", options: .regularExpression)
    }
}
