//
//  FileShelfController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class FileShelfController: ObservableObject {
    static let shared = FileShelfController()

    @Published private(set) var lastStatus = "File shelf is off."

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var observer: NSObjectProtocol?
    private var lastPoint: CGPoint?
    private var dragStartedAt = Date.distantPast
    private var dragOrigin: CGPoint?
    private var lastDragDate = Date.distantPast
    private var lastHorizontalDirection = 0
    private var horizontalDirectionChanges = 0
    private var dragLikelyHasFiles = false
    private var lastTriggeredPoint: CGPoint?
    private var lastTriggeredAt = Date.distantPast
    private var lastShelfFire = Date.distantPast
    private let hotKeyID = EventHotKeyID(signature: OSType(0x46534846), id: 1)
    private let shelfWindow = FileShelfWindowController()

    func start() {
        observeChanges()
        reload()
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
    }

    func showShelf() {
        guard FileShelfStore.isEnabled else { return }
        shelfWindow.show()
        lastStatus = "Shelf shown."
        log("shown")
    }

    private func observeChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: FileShelfStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    private func reload() {
        unregisterHotKey()
        uninstallEventTap()
        lastPoint = nil
        resetShakeState()

        guard FileShelfStore.isEnabled else {
            lastStatus = "File shelf is off."
            shelfWindow.hide()
            return
        }

        registerHotKey()
        installEventTap()
    }

    private func registerHotKey() {
        guard hotKeyRef == nil else { return }
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install shelf shortcut."
            log("InstallEventHandler failed")
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Y),
            UInt32(cmdKey | optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            lastStatus = "Shelf ready: shake selected files or press Command-Option-Shift-Y."
            log("hotkey registered")
        } else {
            lastStatus = "Shelf shortcut could not register."
            log("RegisterEventHotKey failed \(status)")
        }
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
                      hotKeyID.signature == OSType(0x46534846),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<FileShelfController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.shelfWindow.toggle()
                    controller.lastStatus = "Shelf toggled."
                    controller.log("hotkey toggled")
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

    private func installEventTap() {
        guard eventTap == nil else { return }

        let mask = 1 << CGEventType.leftMouseDragged.rawValue
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userData in
                guard let userData else {
                    return Unmanaged.passUnretained(event)
                }

                let controller = Unmanaged<FileShelfController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                controller.handleMouseEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            lastStatus = "Shelf shortcut works. Mouse flick needs Accessibility/Input Monitoring."
            log("event tap unavailable")
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        log("event tap installed")
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

    private func handleMouseEvent(type: CGEventType, event: CGEvent) {
        guard FileShelfStore.isEnabled else { return }
        guard type == .leftMouseDragged else { return }

        let now = Date()
        let point = event.location
        defer {
            lastPoint = point
            lastDragDate = now
        }

        hideMistakenShelfIfNeeded(point: point, now: now)

        if now.timeIntervalSince(lastDragDate) > 0.28 {
            resetShakeState(origin: point, now: now)
        }

        guard dragLikelyHasFiles else { return }
        guard let dragOrigin else { return }
        guard let lastPoint else { return }

        let elapsed = now.timeIntervalSince(lastDragDate)
        guard elapsed > 0, elapsed < 0.18 else { return }
        let dx = point.x - lastPoint.x
        let travelFromOrigin = hypot(point.x - dragOrigin.x, point.y - dragOrigin.y)

        if travelFromOrigin > 280 || abs(point.y - dragOrigin.y) > 170 {
            resetShakeState(origin: point, now: now)
            return
        }

        guard abs(dx) > 14 else { return }
        let direction = dx > 0 ? 1 : -1

        if lastHorizontalDirection == 0 {
            lastHorizontalDirection = direction
            return
        }

        if direction != lastHorizontalDirection {
            horizontalDirectionChanges += 1
            lastHorizontalDirection = direction
        }

        guard now.timeIntervalSince(dragStartedAt) < 1.8 else {
            resetShakeState(origin: point, now: now)
            return
        }
        guard horizontalDirectionChanges >= 5 else { return }
        guard now.timeIntervalSince(lastShelfFire) > 1.1 else { return }

        lastShelfFire = now
        lastTriggeredPoint = point
        lastTriggeredAt = now
        shelfWindow.show()
        lastStatus = "Shelf shown from selected-file shake."
        log("shake trigger reversals=\(horizontalDirectionChanges) travel=\(Int(travelFromOrigin))")
    }

    private func resetShakeState(origin: CGPoint? = nil, now: Date = Date()) {
        lastPoint = origin
        dragOrigin = origin
        dragStartedAt = now
        lastDragDate = now
        lastHorizontalDirection = 0
        horizontalDirectionChanges = 0
        dragLikelyHasFiles = origin == nil ? false : finderHasSelectedFiles()
    }

    private func hideMistakenShelfIfNeeded(point: CGPoint, now: Date) {
        guard FileShelfStore.currentURLs().isEmpty else { return }
        guard let lastTriggeredPoint else { return }
        guard now.timeIntervalSince(lastTriggeredAt) < 1.6 else { return }

        let travelAfterTrigger = hypot(point.x - lastTriggeredPoint.x, point.y - lastTriggeredPoint.y)
        if travelAfterTrigger > 360 {
            shelfWindow.hide()
            self.lastTriggeredPoint = nil
            lastStatus = "Shelf auto-closed after long drag."
            log("auto closed mistaken shelf travel=\(Int(travelAfterTrigger))")
        }
    }

    private func finderHasSelectedFiles() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else {
            return false
        }

        let script = """
        tell application "Finder"
            if (count of selection) is greater than 0 then
                return "yes"
            else
                return "no"
            end if
        end tell
        """

        var error: NSDictionary?
        let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
        if let error {
            log("finder selection check failed \(error)")
        }
        return output == "yes"
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2 FileShelf: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-fileshelf.log")

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
