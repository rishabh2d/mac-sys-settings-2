//
//  AutoScrollController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class AutoScrollController: ObservableObject {
    @Published private(set) var lastStatus = "Control-Option-Command-A is ready."

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private var scrollTimer: Timer?
    private var activeChoice: AutoScrollChoice?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x41534352), id: 1)
    private let presenter = AutoScrollOverlayPresenter()

    func start() {
        observeChanges()
        registerHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observeChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: AutoScrollStore.didChangeNotification,
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
        if !AutoScrollStore.isEnabled {
            stopScrolling()
            presenter.hide()
        }
        registerHotKey()
    }

    private func registerHotKey() {
        guard AutoScrollStore.isEnabled, hotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install autoscroll shortcut."
            log("InstallEventHandler failed")
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_A),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            lastStatus = "Control-Option-Command-A is ready."
            log("autoscroll shortcut registered")
        } else {
            lastStatus = "Control-Option-Command-A could not register."
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
                      hotKeyID.signature == OSType(0x41534352),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<AutoScrollController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.toggleChooserOrStop()
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

    private func toggleChooserOrStop() {
        if scrollTimer != nil {
            stopScrolling()
            return
        }

        presenter.show { [weak self] choice in
            self?.startScrolling(choice)
        } onCancel: { [weak self] in
            self?.stopScrolling()
        }
    }

    private func startScrolling(_ choice: AutoScrollChoice) {
        stopScrolling()
        activeChoice = choice
        lastStatus = "Autoscrolling \(choice.title)."
        log("started \(choice.title)")

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.postScrollTick()
            }
        }
        RunLoop.main.add(scrollTimer!, forMode: .common)
    }

    private func stopScrolling() {
        if scrollTimer != nil {
            log("stopped")
        }
        scrollTimer?.invalidate()
        scrollTimer = nil
        activeChoice = nil
        lastStatus = "Autoscroll stopped."
    }

    private func postScrollTick() {
        guard let choice = activeChoice else { return }
        let delta = choice.direction.sign * choice.speed.wheelDelta
        let source = CGEventSource(stateID: .hidSystemState)

        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            return
        }

        if let mouseEvent = CGEvent(source: nil) {
            event.location = mouseEvent.location
        }

        event.post(tap: .cghidEventTap)
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2 AutoScroll: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-autoscroll.log")

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
