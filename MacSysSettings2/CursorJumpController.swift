//
//  CursorJumpController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class CursorJumpController: ObservableObject {
    static let shared = CursorJumpController()

    @Published private(set) var lastStatus = "\(CursorJumpStore.shortcutText) is ready."

    private var hotKeyRef: EventHotKeyRef?
    private var locatorHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var observer: NSObjectProtocol?
    private var lastEventTapFire = Date.distantPast
    private let hotKeyID = EventHotKeyID(signature: OSType(0x43524A50), id: 1)
    private let locatorHotKeyID = EventHotKeyID(signature: OSType(0x43524A50), id: 2)
    private let presenter = CursorJumpOverlayPresenter()
    private let locatorPresenter = CursorLocatorPresenter.shared
    private var shortcut = CursorJumpStore.currentShortcut()
    private var locatorShortcut = CursorJumpStore.currentLocatorShortcut()
    private var selectedMonitorNumber: Int?
    private var isCursorModeOpen = false

    func start() {
        observeChanges()
        registerHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let locatorHotKeyRef {
            UnregisterEventHotKey(locatorHotKeyRef)
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
    }

    private func observeChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: CursorJumpStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadHotKey()
            }
        }
    }

    private func reloadHotKey() {
        unregisterHotKey()
        if !CursorJumpStore.isEnabled {
            presenter.hide()
            selectedMonitorNumber = nil
        }
        shortcut = CursorJumpStore.currentShortcut()
        locatorShortcut = CursorJumpStore.currentLocatorShortcut()
        registerHotKey()
    }

    private func registerHotKey() {
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install cursor jump shortcut."
            log("InstallEventHandler failed")
            return
        }

        if CursorJumpStore.isEnabled, hotKeyRef == nil {
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                lastStatus = "\(CursorJumpStore.shortcutText) is ready."
                log("cursor jump shortcut registered")
            } else {
                lastStatus = "\(CursorJumpStore.shortcutText) could not register."
                log("RegisterEventHotKey failed \(status)")
            }
        }

        if CursorJumpStore.locatorEnabled, locatorHotKeyRef == nil {
            let status = RegisterEventHotKey(
                locatorShortcut.keyCode,
                locatorShortcut.carbonModifiers,
                locatorHotKeyID,
                GetApplicationEventTarget(),
                0,
                &locatorHotKeyRef
            )

            if status == noErr {
                log("cursor locator shortcut registered")
            } else {
                log("cursor locator RegisterEventHotKey failed \(status)")
            }
        }

        installEventTapIfNeeded()
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let locatorHotKeyRef {
            UnregisterEventHotKey(locatorHotKeyRef)
            self.locatorHotKeyRef = nil
        }
        uninstallEventTap()
    }

    private func installEventTapIfNeeded() {
        guard eventTap == nil else { return }
        guard shouldUseHardwareF2Fallback else { return }

        let systemDefinedEventType = 14
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << systemDefinedEventType)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userData in
                guard let userData else {
                    return Unmanaged.passUnretained(event)
                }

                let controller = Unmanaged<CursorJumpController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                if controller.handleFallbackEvent(type: type, event: event) {
                    return nil
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            log("Command-F2 hardware fallback event tap unavailable")
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        log("Command-F2 hardware fallback event tap installed")
    }

    private func uninstallEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        eventTapRunLoopSource = nil
        eventTap = nil
    }

    private var shouldUseHardwareF2Fallback: Bool {
        CursorJumpStore.isEnabled
        && shortcut.keyCode == UInt32(kVK_F2)
        && shortcut.carbonModifiers == UInt32(cmdKey)
    }

    private func handleFallbackEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard CursorJumpStore.isEnabled else { return false }

        if type == .keyDown, isCursorClickEvent(event, requiresShift: true) {
            clickCurrentCursor(button: .right)
            log("Option-Shift-Z right clicked current cursor")
            return true
        }

        if type == .keyDown, isCursorClickEvent(event, requiresShift: false) {
            clickCurrentCursor(button: .left)
            log("Option-Z left clicked current cursor")
            return true
        }

        guard shouldUseHardwareF2Fallback else { return false }
        guard Date().timeIntervalSince(lastEventTapFire) > 0.35 else { return true }

        let shouldFire: Bool
        if type == .keyDown {
            shouldFire = event.flags.contains(.maskCommand)
                && event.getIntegerValueField(.keyboardEventKeycode) == kVK_F2
        } else if type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event) {
            shouldFire = nsEvent.modifierFlags.contains(.command) && isBrightnessUpKeyDown(nsEvent)
        } else {
            shouldFire = false
        }

        guard shouldFire else { return false }
        lastEventTapFire = Date()
        Task { @MainActor [weak self] in
            self?.showMonitorChooser()
        }
        log("Command-F2 hardware fallback fired")
        return true
    }

    private func isCursorClickEvent(_ event: CGEvent, requiresShift: Bool) -> Bool {
        let flags = event.flags
        return event.getIntegerValueField(.keyboardEventKeycode) == kVK_ANSI_Z
            && flags.contains(.maskAlternate)
            && flags.contains(.maskShift) == requiresShift
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
    }

    private enum CursorClickButton {
        case left
        case right
    }

    private func clickCurrentCursor(button: CursorClickButton) {
        guard let event = CGEvent(source: nil) else { return }
        let location = event.location
        let source = CGEventSource(stateID: .hidSystemState)
        let mouseButton: CGMouseButton = button == .left ? .left : .right
        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

        CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: location, mouseButton: mouseButton)?.post(tap: .cghidEventTap)
        usleep(35_000)
        CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: location, mouseButton: mouseButton)?.post(tap: .cghidEventTap)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }

    private func isBrightnessUpKeyDown(_ event: NSEvent) -> Bool {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return false }
        let data = event.data1
        let keyCode = (data & 0xFFFF0000) >> 16
        let keyState = (data & 0x0000FF00) >> 8
        let isKeyDown = keyState == 0x0A
        return keyCode == 2 && isKeyDown
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
                      hotKeyID.signature == OSType(0x43524A50) else {
                    return noErr
                }

                let controller = Unmanaged<CursorJumpController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    switch hotKeyID.id {
                    case 1:
                        controller.showMonitorChooser()
                    case 2:
                        controller.showCursorLocator()
                    default:
                        break
                    }
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

    private func showMonitorChooser() {
        selectedMonitorNumber = nil
        presenter.show(step: .monitor) { [weak self] digit in
            self?.handleMonitorDigit(digit)
        } onShortcutKey: { [weak self] key in
            self?.handleMonitorShortcutKey(key) ?? false
        } onMove: { [weak self] delta in
            self?.moveCursor(by: delta)
        } onCommit: { [weak self] in
            self?.clickAndExit()
        } onCancel: { [weak self] in
            self?.cancel()
        }
        isCursorModeOpen = true
    }

    private func showCursorLocator() {
        locatorPresenter.show()
        lastStatus = "Cursor locator shown."
        log("cursor locator shown")
    }

    private func handleMonitorDigit(_ digit: Int) {
        guard digit == 1 || digit == 2 else { return }
        selectedMonitorNumber = digit
        presenter.show(step: .point(monitorNumber: digit)) { [weak self] pointDigit in
            self?.handlePointDigit(pointDigit)
        } onShortcutKey: { [weak self] key in
            self?.handlePointShortcutKey(key) ?? false
        } onMove: { [weak self] delta in
            self?.moveCursor(by: delta)
        } onCommit: { [weak self] in
            self?.clickAndExit()
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }

    private func handleMonitorShortcutKey(_ key: String) -> Bool {
        if let pointDigit = pointDigit(for: key, monitorNumber: 1) {
            selectedMonitorNumber = 1
            handlePointDigit(pointDigit)
            showNudgeModeForSelectedMonitor()
            return true
        }

        if let pointDigit = pointDigit(for: key, monitorNumber: 2) {
            selectedMonitorNumber = 2
            handlePointDigit(pointDigit)
            showNudgeModeForSelectedMonitor()
            return true
        }

        return false
    }

    private func handlePointShortcutKey(_ key: String) -> Bool {
        guard let selectedMonitorNumber,
              let pointDigit = pointDigit(for: key, monitorNumber: selectedMonitorNumber) else {
            return false
        }

        handlePointDigit(pointDigit)
        return true
    }

    private func pointDigit(for key: String, monitorNumber: Int) -> Int? {
        if monitorNumber == 2 {
            return [
                "u": 1, "i": 2, "o": 3,
                "j": 4, "k": 5, "l": 6,
                "n": 7, "m": 8, ",": 9
            ][key]
        }

        return [
            "q": 1, "w": 2, "e": 3,
            "a": 4, "s": 5, "d": 6,
            "z": 7, "x": 8, "c": 9
        ][key]
    }

    private func showPointPickerForSelectedMonitor() {
        guard let selectedMonitorNumber else { return }
        presenter.show(step: .point(monitorNumber: selectedMonitorNumber)) { [weak self] pointDigit in
            self?.handlePointDigit(pointDigit)
        } onShortcutKey: { [weak self] key in
            self?.handlePointShortcutKey(key) ?? false
        } onMove: { [weak self] delta in
            self?.moveCursor(by: delta)
        } onCommit: { [weak self] in
            self?.clickAndExit()
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }

    private func showNudgeModeForSelectedMonitor() {
        guard let selectedMonitorNumber else { return }
        presenter.show(step: .nudge(monitorNumber: selectedMonitorNumber)) { [weak self] pointDigit in
            self?.handlePointDigit(pointDigit)
        } onShortcutKey: { [weak self] key in
            self?.handlePointShortcutKey(key) ?? false
        } onMove: { [weak self] delta in
            self?.moveCursor(by: delta)
        } onCommit: { [weak self] in
            self?.clickAndExit()
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }

    private func handlePointDigit(_ digit: Int) {
        guard let monitorNumber = selectedMonitorNumber else { return }
        guard let target = screen(forMonitorNumber: monitorNumber) else {
            lastStatus = "Monitor \(monitorNumber) was not found."
            log("monitor \(monitorNumber) not found")
            cancel()
            return
        }

        let point = cursorPoint(on: target.screen, digit: digit)
        let error = CGDisplayMoveCursorToPoint(target.displayID, point)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        if error != .success {
            log("CGDisplayMoveCursorToPoint failed \(error.rawValue)")
        }
        lastStatus = "Cursor jumped to monitor \(monitorNumber), point \(digit)."
        log("jumped to monitor \(monitorNumber), point \(digit), \(Int(point.x)),\(Int(point.y))")
        focusWindowUnderCursor()
        showLocatorAfterJumpIfNeeded()
    }

    private func moveCursor(by delta: CGSize) {
        guard let event = CGEvent(source: nil) else { return }
        let current = event.location
        let target = CGPoint(x: current.x + delta.width, y: current.y + delta.height)
        CGWarpMouseCursorPosition(target)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        lastStatus = "Cursor moved."
        log("cursor moved by \(Int(delta.width)),\(Int(delta.height))")
        focusWindowUnderCursor()
    }

    private func clickAndExit() {
        clickCurrentCursor(button: .left)
        cancel()
    }

    private func showLocatorAfterJumpIfNeeded() {
        guard CursorJumpStore.locatorAfterJumpEnabled else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000)
            self?.locatorPresenter.show()
        }
    }

    private func cancel() {
        selectedMonitorNumber = nil
        isCursorModeOpen = false
        presenter.hide()
    }

    private func focusWindowUnderCursor() {
        guard let event = CGEvent(source: nil),
              let target = cursorFocusTarget(at: event.location),
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.processIdentifier == target.processIdentifier && !$0.isTerminated
              }) else {
            return
        }

        let appElement = AXUIElementCreateApplication(target.processIdentifier)
        let window = target.window ?? matchingWindow(for: appElement, frame: target.frame)
        guard let window else { return }

        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        setBool(true, attribute: kAXMainAttribute, on: window)
        setBool(true, attribute: kAXFocusedAttribute, on: window)
        app.activate(options: [.activateAllWindows])
        log("focused window under cursor without click")
    }

    private func cursorFocusTarget(at mouseLocation: CGPoint) -> CursorFocusTarget? {
        if let accessibilityTarget = accessibilityWindowUnderCursor(mouseLocation) {
            return accessibilityTarget
        }

        return visibleWindowUnderCursor(mouseLocation)
    }

    private func accessibilityWindowUnderCursor(_ mouseLocation: CGPoint) -> CursorFocusTarget? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(mouseLocation.y), &element) == .success,
              let element,
              let window = containingWindow(for: element) else {
            return nil
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success,
              pid > 0,
              pid != getpid(),
              let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window),
              size.width >= 80,
              size.height >= 60 else {
            return nil
        }

        return CursorFocusTarget(processIdentifier: pid, frame: CGRect(origin: position, size: size), window: window)
    }

    private func visibleWindowUnderCursor(_ mouseLocation: CGPoint) -> CursorFocusTarget? {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return rawWindows.compactMap { info -> CursorFocusTarget? in
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0 else { return nil }

            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != getpid(),
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDictionary),
                  frame.width >= 80,
                  frame.height >= 60,
                  frame.contains(mouseLocation) else {
                return nil
            }

            return CursorFocusTarget(processIdentifier: ownerPID, frame: frame, window: nil)
        }.first
    }

    private func containingWindow(for element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element

        for _ in 0..<8 {
            guard let candidate = current else { return nil }

            if role(of: candidate) == kAXWindowRole as String {
                return candidate
            }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parent) == .success,
                  let parentElement = parent,
                  CFGetTypeID(parentElement) == AXUIElementGetTypeID() else {
                return nil
            }

            current = (parentElement as! AXUIElement)
        }

        return nil
    }

    private func matchingWindow(for appElement: AXUIElement, frame: CGRect) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.first { candidate in
            guard let position = windowPoint(candidate, attribute: kAXPositionAttribute),
                  let size = windowSize(candidate) else { return false }
            return framesAreClose(CGRect(origin: position, size: size), frame)
        }
    }

    private func containingWindowPoint(_ window: AXUIElement) -> CGPoint? {
        windowPoint(window, attribute: kAXPositionAttribute)
    }

    private func windowPoint(_ window: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue((axValue as! AXValue), .cgPoint, &point) else { return nil }
        return point
    }

    private func windowSize(_ window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue((axValue as! AXValue), .cgSize, &size) else { return nil }
        return size
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func setBool(_ bool: Bool, attribute: String, on element: AXUIElement) {
        let value = bool as CFBoolean
        _ = AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func framesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 10
            && abs(lhs.minY - rhs.minY) <= 10
            && abs(lhs.width - rhs.width) <= 20
            && abs(lhs.height - rhs.height) <= 20
    }

    private func screen(forMonitorNumber monitorNumber: Int) -> CursorJumpScreen? {
        let screens = orderedScreens()
        let index = monitorNumber - 1
        guard screens.indices.contains(index) else { return nil }
        return screens[index]
    }

    private func orderedScreens() -> [CursorJumpScreen] {
        let screens = NSScreen.screens.compactMap { screen -> CursorJumpScreen? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return CursorJumpScreen(screen: screen, displayID: CGDirectDisplayID(number.uint32Value))
        }
        guard screens.count > 1 else { return screens }

        let builtIn = screens.first { screen in
            let name = screen.screen.localizedName.lowercased()
            return name.contains("built-in") || name.contains("retina") || name.contains("color lcd")
        } ?? screens.first { candidate in
            guard let main = NSScreen.main else { return false }
            return candidate.screen == main
        }

        var ordered: [NSScreen] = []
        if let builtIn {
            ordered.append(builtIn.screen)
        }
        ordered.append(contentsOf: screens.map(\.screen).filter { candidate in
            !ordered.contains(where: { $0 == candidate })
        }.sorted { lhs, rhs in
            if lhs.frame.minX == rhs.frame.minX {
                return lhs.frame.minY > rhs.frame.minY
            }
            return lhs.frame.minX < rhs.frame.minX
        })
        return ordered.compactMap { screen in
            screens.first { $0.screen == screen }
        }
    }

    private func otherScreenIndex(from screens: [CursorJumpScreen]) -> Int? {
        guard screens.count == 2, let event = CGEvent(source: nil) else { return nil }

        let mouseLocation = event.location
        if let currentIndex = screens.firstIndex(where: { $0.bounds.contains(mouseLocation) }) {
            return currentIndex == 0 ? 1 : 0
        }

        return 1
    }

    private func cursorPoint(on screen: NSScreen, digit: Int) -> CGPoint {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return .zero
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        let bounds = CGDisplayBounds(displayID)
        let frame = CGRect(origin: .zero, size: bounds.size)
        let x: CGFloat
        let y: CGFloat

        switch digit {
        case 1, 4, 7:
            x = frame.minX + frame.width * 0.25
        case 3, 6, 9:
            x = frame.minX + frame.width * 0.75
        default:
            x = frame.midX
        }

        switch digit {
        case 1, 2, 3:
            y = frame.minY + frame.height * 0.25
        case 7, 8, 9:
            y = frame.minY + frame.height * 0.75
        default:
            y = frame.midY
        }

        return CGPoint(x: x, y: y)
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2 CursorJump: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-cursorjump.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}

private struct CursorJumpScreen {
    let screen: NSScreen
    let displayID: CGDirectDisplayID

    var bounds: CGRect {
        CGDisplayBounds(displayID)
    }
}

private struct CursorFocusTarget {
    let processIdentifier: pid_t
    let frame: CGRect
    let window: AXUIElement?
}
