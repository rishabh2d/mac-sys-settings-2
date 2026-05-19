//
//  ScreenShortcutController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class ScreenShortcutController: ObservableObject {
    @Published private(set) var lastStatus = "\(ScreenShortcut.current().displayText) is ready."

    private var moveHotKeyRef: EventHotKeyRef?
    private var pairedMoveHotKeyRef: EventHotKeyRef?
    private var leftSnapHotKeyRef: EventHotKeyRef?
    private var rightSnapHotKeyRef: EventHotKeyRef?
    private var controlArrowGlobalMonitor: Any?
    private var controlArrowLocalMonitor: Any?
    private var controlArrowEventTap: CFMachPort?
    private var controlArrowRunLoopSource: CFRunLoopSource?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature = OSType(0x4D535332)
    private let moveHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 1)
    private let pairedMoveHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 4)
    private let leftSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 2)
    private let rightSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 3)
    private var shortcut = ScreenShortcut.current()
    private var shortcutObserver: NSObjectProtocol?
    private var controlArrowObserver: NSObjectProtocol?

    func start() {
        log("ScreenShortcutController starting")
        requestAccessibilityAccess()
        observeShortcutChanges()
        observeControlArrowChanges()
        registerHotKey()
        registerControlArrowHotKeys()
    }

    deinit {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let shortcutObserver {
            NotificationCenter.default.removeObserver(shortcutObserver)
        }
        if let controlArrowObserver {
            NotificationCenter.default.removeObserver(controlArrowObserver)
        }
        if let moveHotKeyRef {
            UnregisterEventHotKey(moveHotKeyRef)
        }
        if let pairedMoveHotKeyRef {
            UnregisterEventHotKey(pairedMoveHotKeyRef)
        }
        if let leftSnapHotKeyRef {
            UnregisterEventHotKey(leftSnapHotKeyRef)
        }
        if let rightSnapHotKeyRef {
            UnregisterEventHotKey(rightSnapHotKeyRef)
        }
        if let controlArrowGlobalMonitor {
            NSEvent.removeMonitor(controlArrowGlobalMonitor)
        }
        if let controlArrowLocalMonitor {
            NSEvent.removeMonitor(controlArrowLocalMonitor)
        }
        if let controlArrowEventTap {
            CGEvent.tapEnable(tap: controlArrowEventTap, enable: false)
        }
        if let controlArrowRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), controlArrowRunLoopSource, .commonModes)
        }
    }

    private func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            lastStatus = "Allow Accessibility permission to move windows."
            log("Accessibility permission is not granted")
        } else {
            log("Accessibility permission is granted")
        }
    }

    private func registerHotKey() {
        guard moveHotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install \(shortcut.displayText) handler."
            return
        }

        let registerStatus = registerMoveHotKey(
            keyCode: shortcut.keyCode,
            hotKeyID: moveHotKeyID,
            ref: &moveHotKeyRef
        )

        if registerStatus == noErr {
            lastStatus = "\(shortcut.displayText) is ready."
            log("\(shortcut.displayText) registered")

            if let pairedMoveKeyCode = shortcut.pairedMoveKeyCode {
                let pairedStatus = registerMoveHotKey(
                    keyCode: pairedMoveKeyCode,
                    hotKeyID: pairedMoveHotKeyID,
                    ref: &pairedMoveHotKeyRef
                )

                if pairedStatus == noErr {
                    log("\(shortcut.displayText) paired arrow registered")
                } else {
                    log("paired RegisterEventHotKey failed \(pairedStatus)")
                }
            }
        } else {
            lastStatus = "\(shortcut.displayText) is already used by another app."
            log("RegisterEventHotKey failed \(registerStatus)")
        }
    }

    private func registerMoveHotKey(keyCode: UInt32, hotKeyID: EventHotKeyID, ref: inout EventHotKeyRef?) -> OSStatus {
        RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
    }

    private func unregisterHotKey() {
        if let moveHotKeyRef {
            UnregisterEventHotKey(moveHotKeyRef)
            self.moveHotKeyRef = nil
        }
        if let pairedMoveHotKeyRef {
            UnregisterEventHotKey(pairedMoveHotKeyRef)
            self.pairedMoveHotKeyRef = nil
        }
    }

    private func ensureEventHandlerInstalled() -> Bool {
        guard eventHandlerRef == nil else { return true }

        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
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

                guard status == noErr, hotKeyID.signature == OSType(0x4D535332) else { return noErr }

                let controller = Unmanaged<ScreenShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.handleHotKey(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            eventTypes,
            selfPointer,
            &eventHandlerRef
        )

        if installStatus != noErr {
            log("InstallEventHandler failed \(installStatus)")
        }

        return installStatus == noErr
    }

    private func handleHotKey(id: UInt32) {
        switch id {
        case moveHotKeyID.id, pairedMoveHotKeyID.id:
            log("\(shortcut.displayText) hotkey pressed")
            moveFrontWindowToNextScreen()
        case leftSnapHotKeyID.id:
            log("Control-Left hotkey pressed")
            snapFrontWindow(to: .left)
        case rightSnapHotKeyID.id:
            log("Control-Right hotkey pressed")
            snapFrontWindow(to: .right)
        default:
            break
        }
    }

    private func observeShortcutChanges() {
        guard shortcutObserver == nil else { return }

        shortcutObserver = NotificationCenter.default.addObserver(
            forName: ScreenShortcut.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadShortcut()
            }
        }
    }

    private func reloadShortcut() {
        let updatedShortcut = ScreenShortcut.current()
        guard updatedShortcut != shortcut else { return }

        unregisterHotKey()
        shortcut = updatedShortcut
        registerHotKey()
        log("shortcut changed to \(shortcut.displayText)")
    }

    private func observeControlArrowChanges() {
        guard controlArrowObserver == nil else { return }

        controlArrowObserver = NotificationCenter.default.addObserver(
            forName: ControlArrowSnapStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func reloadControlArrowHotKeys() {
        unregisterControlArrowHotKeys()
        registerControlArrowHotKeys()
    }

    private func registerControlArrowHotKeys() {
        guard ControlArrowSnapStore.isEnabled else { return }
        registerControlArrowEventTap()
    }

    private func unregisterControlArrowHotKeys() {
        if let leftSnapHotKeyRef {
            UnregisterEventHotKey(leftSnapHotKeyRef)
            self.leftSnapHotKeyRef = nil
        }
        if let rightSnapHotKeyRef {
            UnregisterEventHotKey(rightSnapHotKeyRef)
            self.rightSnapHotKeyRef = nil
        }
        unregisterControlArrowMonitors()
        unregisterControlArrowEventTap()
    }

    private func registerControlArrowEventTap() {
        guard controlArrowEventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }

                let controller = Unmanaged<ScreenShortcutController>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let eventTap = controller.controlArrowEventTap {
                        CGEvent.tapEnable(tap: eventTap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown, controller.isControlArrowEvent(event) else {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                Task { @MainActor in
                    if keyCode == Int64(kVK_LeftArrow) {
                        controller.log("Control-Left event tap pressed")
                        controller.snapFrontWindow(to: .left)
                    } else if keyCode == Int64(kVK_RightArrow) {
                        controller.log("Control-Right event tap pressed")
                        controller.snapFrontWindow(to: .right)
                    }
                }

                return nil
            },
            userInfo: selfPointer
        ) else {
            log("Control-Arrow event tap failed")
            registerControlArrowMonitors()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        controlArrowEventTap = eventTap
        controlArrowRunLoopSource = source
        log("Control-Arrow event tap registered")
    }

    private func unregisterControlArrowEventTap() {
        if let controlArrowEventTap {
            CGEvent.tapEnable(tap: controlArrowEventTap, enable: false)
            self.controlArrowEventTap = nil
        }
        if let controlArrowRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), controlArrowRunLoopSource, .commonModes)
            self.controlArrowRunLoopSource = nil
        }
    }

    private func registerControlArrowMonitors() {
        guard controlArrowGlobalMonitor == nil, controlArrowLocalMonitor == nil else { return }

        controlArrowGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleControlArrowEvent(event)
            }
        }

        controlArrowLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isControlArrowEvent(event) {
                Task { @MainActor in
                    self?.handleControlArrowEvent(event)
                }
                return nil
            }

            return event
        }

        log("Control-Arrow monitor registered")
    }

    private func unregisterControlArrowMonitors() {
        if let controlArrowGlobalMonitor {
            NSEvent.removeMonitor(controlArrowGlobalMonitor)
            self.controlArrowGlobalMonitor = nil
        }
        if let controlArrowLocalMonitor {
            NSEvent.removeMonitor(controlArrowLocalMonitor)
            self.controlArrowLocalMonitor = nil
        }
    }

    private func handleControlArrowEvent(_ event: NSEvent) {
        guard Self.isControlArrowEvent(event) else { return }

        if event.keyCode == UInt16(kVK_LeftArrow) {
            log("Control-Left event pressed")
            snapFrontWindow(to: .left)
        } else if event.keyCode == UInt16(kVK_RightArrow) {
            log("Control-Right event pressed")
            snapFrontWindow(to: .right)
        }
    }

    private static func isControlArrowEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            && !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.shift)
            && (event.keyCode == UInt16(kVK_LeftArrow) || event.keyCode == UInt16(kVK_RightArrow))
    }

    private nonisolated func isControlArrowEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskControl)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && (keyCode == Int64(kVK_LeftArrow) || keyCode == Int64(kVK_RightArrow))
    }

    private func moveFrontWindowToNextScreen() {
        guard AXIsProcessTrusted() else {
            log("move blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            lastStatus = "No front app found."
            log("no front app found")
            return
        }

        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            moveOwnWindowToNextScreen()
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else {
            lastStatus = "No focused window found for \(app.localizedName ?? "front app")."
            log("no focused window for \(app.localizedName ?? "front app")")
            return
        }

        guard NSScreen.screens.count > 1 else {
            lastStatus = "Only one screen is connected."
            log("only one screen connected")
            return
        }

        guard let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            lastStatus = "Could not read the front window frame."
            log("could not read window frame")
            return
        }

        let currentFrame = CGRect(origin: position, size: size)
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        let currentScreen = screens.first { $0.frame.intersects(currentFrame) } ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }

        let targetScreen = screens[(currentIndex + 1) % screens.count]
        let newFrame = preservingRelativeFrame(
            currentFrame,
            from: currentScreen,
            to: targetScreen,
            usesAccessibilityCoordinates: true
        )

        setWindow(window, position: newFrame.origin, size: newFrame.size)
        lastStatus = "Moved \(app.localizedName ?? "window") to Screen \((screens.firstIndex(of: targetScreen) ?? 0) + 1)."
        log("moved \(app.localizedName ?? "window") from \(currentFrame) to \(newFrame)")
    }

    private func focusedWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let window = value {
            return (window as! AXUIElement)
        }

        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement] {
            return windows.first
        }

        return nil
    }

    private func moveOwnWindowToNextScreen() {
        guard NSScreen.screens.count > 1 else {
            lastStatus = "Only one screen is connected."
            log("only one screen connected")
            return
        }

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            lastStatus = "No Mac Sys Settings 2 window found."
            log("no self window found")
            return
        }

        let currentFrame = window.frame
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        let currentScreen = screens.first { $0.frame.intersects(currentFrame) } ?? window.screen ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }

        let targetScreen = screens[(currentIndex + 1) % screens.count]
        let newFrame = preservingRelativeFrame(
            currentFrame,
            from: currentScreen,
            to: targetScreen,
            usesAccessibilityCoordinates: false
        )

        window.setFrame(newFrame, display: true, animate: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lastStatus = "Moved Mac Sys Settings 2 to Screen \((screens.firstIndex(of: targetScreen) ?? 0) + 1)."
        log("moved self from \(currentFrame) to \(newFrame)")
    }

    private enum SnapSide {
        case left
        case right
    }

    private func snapFrontWindow(to side: SnapSide) {
        guard AXIsProcessTrusted() else {
            log("snap blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            lastStatus = "No front app found."
            log("no front app found for snap")
            return
        }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            snapOwnWindow(to: side)
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else {
            lastStatus = "No focused window found for \(app.localizedName ?? "front app")."
            log("no focused window for snap \(app.localizedName ?? "front app")")
            return
        }

        guard let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            lastStatus = "Could not read the front window frame."
            log("could not read window frame for snap")
            return
        }

        let currentFrame = CGRect(origin: position, size: size)
        let screen = accessibilityScreen(for: currentFrame) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = accessibilityScreenFrame(for: screen)
        let newFrame = snappingFrame(for: currentFrame, in: screenFrame, side: side)

        setWindow(window, position: newFrame.origin, size: newFrame.size)
        lastStatus = side == .left ? "Snapped left." : "Snapped right."
        log("snapped \(app.localizedName ?? "window") \(side) from \(currentFrame) to \(newFrame)")
    }

    private func snapOwnWindow(to side: SnapSide) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            lastStatus = "No Mac Sys Settings 2 window found."
            log("no self window found for snap")
            return
        }

        let currentFrame = window.frame
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let newFrame = snappingFrame(for: currentFrame, in: screen.visibleFrame, side: side)

        window.setFrame(newFrame, display: true, animate: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lastStatus = side == .left ? "Snapped left." : "Snapped right."
        log("snapped self \(side) from \(currentFrame) to \(newFrame)")
    }

    private func snappingFrame(for currentFrame: CGRect, in screenFrame: CGRect, side: SnapSide) -> CGRect {
        let fractions: [CGFloat] = [0.5, 1.0 / 3.0, 2.0 / 3.0]
        let currentFraction = screenFrame.width == 0 ? 0.5 : currentFrame.width / screenFrame.width
        let edgeThreshold: CGFloat = 36
        let isOnRequestedSide: Bool

        switch side {
        case .left:
            isOnRequestedSide = abs(currentFrame.minX - screenFrame.minX) <= edgeThreshold
        case .right:
            isOnRequestedSide = abs(currentFrame.maxX - screenFrame.maxX) <= edgeThreshold
        }

        let targetFraction: CGFloat
        if isOnRequestedSide,
           let currentIndex = fractions.firstIndex(where: { abs(currentFraction - $0) <= 0.08 }) {
            targetFraction = fractions[(currentIndex + 1) % fractions.count]
        } else {
            targetFraction = fractions[0]
        }

        let width = max(160, screenFrame.width * targetFraction)
        let x = side == .left ? screenFrame.minX : screenFrame.maxX - width

        return CGRect(
            x: x,
            y: screenFrame.minY,
            width: width,
            height: screenFrame.height
        )
    }

    private func accessibilityScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens
            .map { screen -> (screen: NSScreen, area: CGFloat) in
                let intersection = accessibilityScreenFrame(for: screen).intersection(frame)
                return (screen, intersection.isNull ? 0 : intersection.width * intersection.height)
            }
            .max { $0.area < $1.area }?
            .screen
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

    private func preservingRelativeFrame(
        _ windowFrame: CGRect,
        from sourceScreen: NSScreen,
        to targetScreen: NSScreen,
        usesAccessibilityCoordinates: Bool
    ) -> CGRect {
        let source = usesAccessibilityCoordinates
            ? accessibilityScreenFrame(for: sourceScreen)
            : sourceScreen.visibleFrame
        let target = usesAccessibilityCoordinates
            ? accessibilityScreenFrame(for: targetScreen)
            : targetScreen.visibleFrame

        let edgeThreshold: CGFloat = 24
        let verticalEdgeThreshold: CGFloat = usesAccessibilityCoordinates ? 96 : edgeThreshold
        let touchesLeft = abs(windowFrame.minX - source.minX) <= edgeThreshold
        let touchesRight = abs(windowFrame.maxX - source.maxX) <= edgeThreshold
        let touchesBottom = abs(windowFrame.maxY - source.maxY) <= verticalEdgeThreshold
        let touchesTop = abs(windowFrame.minY - source.minY) <= verticalEdgeThreshold

        let relativeMinX = source.width == 0 ? 0 : (windowFrame.minX - source.minX) / source.width
        let relativeMinY = source.height == 0 ? 0 : (windowFrame.minY - source.minY) / source.height
        let relativeWidth = source.width == 0 ? 1 : windowFrame.width / source.width
        let relativeHeight = source.height == 0 ? 1 : windowFrame.height / source.height
        let isHalfWidth = abs(relativeWidth - 0.5) <= 0.08
        let isLeftHalf = touchesLeft && isHalfWidth && !touchesRight
        let isRightHalf = touchesRight && isHalfWidth && !touchesLeft

        let maxWidth = max(160, target.width)
        let maxHeight = max(120, target.height)
        let width: CGFloat
        if touchesLeft && touchesRight {
            width = target.width
        } else if isLeftHalf || isRightHalf {
            width = target.width / 2
        } else {
            width = min(max(160, target.width * relativeWidth), maxWidth)
        }
        let height = touchesTop && touchesBottom
            ? target.height
            : min(max(120, target.height * relativeHeight), maxHeight)

        let rawX: CGFloat
        if touchesLeft {
            rawX = target.minX
        } else if touchesRight {
            rawX = target.maxX - width
        } else {
            rawX = target.minX + target.width * relativeMinX
        }

        let rawY: CGFloat
        if touchesTop {
            rawY = target.minY
        } else if touchesBottom {
            rawY = target.maxY - height
        } else {
            rawY = target.minY + target.height * relativeMinY
        }

        let x = min(max(rawX, target.minX), target.maxX - width)
        let y = min(max(rawY, target.minY), target.maxY - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func accessibilityScreenFrame(for screen: NSScreen) -> CGRect {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return CGRect(
                x: screen.visibleFrame.minX,
                y: screen.frame.maxY - screen.visibleFrame.maxY,
                width: screen.visibleFrame.width,
                height: screen.visibleFrame.height
            )
        }

        let displayBounds = CGDisplayBounds(screenNumber)
        let topInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let usableTop = displayBounds.minY + topInset
        let usableBottom = displayBounds.maxY
        let usableHeight = max(120, usableBottom - usableTop)

        return CGRect(
            x: screen.visibleFrame.minX,
            y: usableTop,
            width: screen.visibleFrame.width,
            height: usableHeight
        )
    }

    private func setWindow(_ window: AXUIElement, position: CGPoint, size: CGSize) {
        var mutablePosition = position
        var mutableSize = size

        guard let positionValue = AXValueCreate(.cgPoint, &mutablePosition),
              let sizeValue = AXValueCreate(.cgSize, &mutableSize) else {
            return
        }

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-screen.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
