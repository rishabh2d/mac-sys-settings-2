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
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << systemDefinedEventType)
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
        guard shouldUseHardwareF2Fallback else { return false }
        guard event.flags.contains(.maskCommand) else { return false }
        guard Date().timeIntervalSince(lastEventTapFire) > 0.35 else { return true }

        let shouldFire: Bool
        if type == .keyDown {
            shouldFire = event.getIntegerValueField(.keyboardEventKeycode) == kVK_F2
        } else if type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event) {
            shouldFire = isBrightnessUpKeyDown(nsEvent)
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
        } onCancel: { [weak self] in
            self?.cancel()
        }
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
        presenter.hide()
        selectedMonitorNumber = nil
        showLocatorAfterJumpIfNeeded()
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
        presenter.hide()
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
