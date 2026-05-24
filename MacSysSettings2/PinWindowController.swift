//
//  PinWindowController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/24/26.
//

import AppKit
import Carbon
import Combine
import Darwin
import Foundation

@MainActor
final class PinWindowController: ObservableObject {
    static let shared = PinWindowController()

    @Published private(set) var lastStatus = "Ready"
    @Published private(set) var pinnedCount = 0

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var observer: NSObjectProtocol?
    private var raiseTimer: Timer?
    private var pinnedWindows: [CGWindowID: PinnedWindow] = [:]
    private let hotKeyID = EventHotKeyID(signature: OSType(0x50494E57), id: 1)

    func start() {
        observeChanges()
        registerHotKey()
        registerEventTap()
    }

    func toggleFocusedWindow() {
        guard PinWindowStore.isEnabled else {
            lastStatus = "Setting is off"
            return
        }

        guard let target = focusedWindowTarget() else {
            lastStatus = "No focused window"
            return
        }

        if pinnedWindows[target.windowID] != nil {
            unpin(target.windowID, title: target.title)
        } else {
            pin(target)
        }
    }

    func unpinAll() {
        for windowID in pinnedWindows.keys {
            _ = Self.setWindowLevel(windowID: windowID, level: Self.normalWindowLevel)
        }
        pinnedWindows.removeAll()
        pinnedCount = 0
        stopRaiseTimerIfNeeded()
        lastStatus = "Unpinned all"
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
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
        raiseTimer?.invalidate()
        for windowID in pinnedWindows.keys {
            _ = Self.setWindowLevel(windowID: windowID, level: Self.normalWindowLevel)
        }
    }

    private func observeChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: PinWindowStore.didChangeNotification,
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
        unregisterEventTap()
        if !PinWindowStore.isEnabled {
            unpinAll()
        }
        registerHotKey()
        registerEventTap()
    }

    private func registerHotKey() {
        guard PinWindowStore.isEnabled, hotKeyRef == nil else { return }
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install \(PinWindowStore.shortcut.displayText)"
            return
        }

        let shortcut = PinWindowStore.shortcut
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        lastStatus = status == noErr ? "\(shortcut.displayText) ready" : "\(shortcut.displayText) could not register"
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func registerEventTap() {
        guard PinWindowStore.isEnabled, eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }

            let controller = Unmanaged<PinWindowController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard PinWindowStore.isEnabled, controller.isPinShortcut(event) else {
                return Unmanaged.passUnretained(event)
            }

            Task { @MainActor in
                controller.toggleFocusedWindow()
            }
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            lastStatus = "Could not install \(PinWindowStore.shortcut.displayText)"
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

    private func isPinShortcut(_ event: CGEvent) -> Bool {
        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == PinWindowStore.shortcut.keyCode else {
            return false
        }

        let flags = event.flags
        return flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskShift)
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
                      hotKeyID.signature == OSType(0x50494E57),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<PinWindowController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.toggleFocusedWindow()
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

    private func pin(_ target: PinWindowTarget) {
        guard Self.setWindowLevel(windowID: target.windowID, level: Self.pinnedWindowLevel) else {
            lastStatus = "Could not pin \(target.title)"
            return
        }

        _ = raise(target.window)
        pinnedWindows[target.windowID] = PinnedWindow(windowID: target.windowID, title: target.title, window: target.window)
        pinnedCount = pinnedWindows.count
        startRaiseTimerIfNeeded()
        lastStatus = "Pinned \(target.title)"
    }

    private func unpin(_ windowID: CGWindowID, title: String) {
        guard Self.setWindowLevel(windowID: windowID, level: Self.normalWindowLevel) else {
            lastStatus = "Could not unpin \(title)"
            return
        }

        pinnedWindows.removeValue(forKey: windowID)
        pinnedCount = pinnedWindows.count
        stopRaiseTimerIfNeeded()
        lastStatus = "Unpinned \(title)"
    }

    private func focusedWindowTarget() -> PinWindowTarget? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value else {
            return nil
        }

        let windowElement = window as! AXUIElement
        guard let windowID = windowID(for: windowElement) else {
            return nil
        }

        let title = stringAttribute(kAXTitleAttribute as CFString, on: windowElement)
            ?? app.localizedName
            ?? "Focused Window"

        return PinWindowTarget(windowID: windowID, title: title.isEmpty ? "Focused Window" : title, window: windowElement)
    }

    private func windowID(for element: AXUIElement) -> CGWindowID? {
        guard let function = DynamicPrivateWindowAPI.axWindowFunction else {
            return nil
        }

        var windowID = CGWindowID(0)
        let error = function(element, &windowID)
        guard error == .success, windowID != 0 else {
            return nil
        }
        return windowID
    }

    private nonisolated static func setWindowLevel(windowID: CGWindowID, level: Int32) -> Bool {
        guard let connectionFunction = DynamicPrivateWindowAPI.connectionFunction,
              let setLevelFunction = DynamicPrivateWindowAPI.setLevelFunction else {
            return false
        }

        let connection = connectionFunction()
        return setLevelFunction(connection, windowID, level) == 0
    }

    private func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func startRaiseTimerIfNeeded() {
        guard raiseTimer == nil else { return }

        raiseTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.raisePinnedWindows()
            }
        }
        raiseTimer?.tolerance = 0.08
    }

    private func stopRaiseTimerIfNeeded() {
        guard pinnedWindows.isEmpty else { return }
        raiseTimer?.invalidate()
        raiseTimer = nil
    }

    private func raisePinnedWindows() {
        var staleWindowIDs: [CGWindowID] = []

        for pinnedWindow in pinnedWindows.values {
            if !raise(pinnedWindow.window) {
                staleWindowIDs.append(pinnedWindow.windowID)
            }
        }

        for windowID in staleWindowIDs {
            pinnedWindows.removeValue(forKey: windowID)
        }

        pinnedCount = pinnedWindows.count
        stopRaiseTimerIfNeeded()
    }

    @discardableResult
    private func raise(_ window: AXUIElement) -> Bool {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success
    }

    private nonisolated static var pinnedWindowLevel: Int32 {
        Int32(CGWindowLevelForKey(.floatingWindow))
    }

    private nonisolated static var normalWindowLevel: Int32 {
        Int32(CGWindowLevelForKey(.normalWindow))
    }
}

private struct PinWindowTarget {
    let windowID: CGWindowID
    let title: String
    let window: AXUIElement
}

private struct PinnedWindow {
    let windowID: CGWindowID
    let title: String
    let window: AXUIElement
}

private enum DynamicPrivateWindowAPI {
    typealias AXWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    typealias ConnectionFunction = @convention(c) () -> UInt32
    typealias SetLevelFunction = @convention(c) (UInt32, CGWindowID, Int32) -> Int32

    nonisolated static let axWindowFunction: AXWindowFunction? = load("_AXUIElementGetWindow")
    nonisolated static let connectionFunction: ConnectionFunction? = load("CGSMainConnectionID")
    nonisolated static let setLevelFunction: SetLevelFunction? = load("CGSSetWindowLevel")

    private nonisolated static func load<T>(_ name: String) -> T? {
        if let symbol = dlsym(nil, name) {
            return unsafeBitCast(symbol, to: T.self)
        }

        for path in frameworkPaths {
            guard let handle = dlopen(path, RTLD_NOW),
                  let symbol = dlsym(handle, name) else {
                continue
            }
            return unsafeBitCast(symbol, to: T.self)
        }

        return nil
    }

    private nonisolated static let frameworkPaths = [
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
        "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices"
    ]
}
