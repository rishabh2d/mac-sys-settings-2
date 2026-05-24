//
//  AutoKeyPressController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/23/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class AutoKeyPressController: ObservableObject {
    static let shared = AutoKeyPressController()

    @Published private(set) var isRunning = false
    @Published private(set) var lastStatus = "Ready"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x414B5052), id: 1)
    private let setupPresenter = AutoKeyPressSetupPresenter()

    func start() {
        observeChanges()
        registerHotKey()
    }

    func stopRepeating() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastStatus = "Stopped"
    }

    func configureAndStart() {
        stopRepeating()
        setupPresenter.show { [weak self] result in
            guard let self else { return }
            guard let result else {
                self.lastStatus = "Setup cancelled"
                return
            }

            AutoKeyPressStore.saveTargetKey(keyCode: result.keyCode, name: result.keyName)
            AutoKeyPressStore.saveInterval(result.interval)
            self.startRepeating()
        }
    }

    deinit {
        timer?.invalidate()
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
            forName: AutoKeyPressStore.didChangeNotification,
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
        registerHotKey()
        if !AutoKeyPressStore.isEnabled {
            stopRepeating()
        }
    }

    private func registerHotKey() {
        guard AutoKeyPressStore.isEnabled, hotKeyRef == nil else { return }
        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install shortcut"
            return
        }

        let shortcut = AutoKeyPressStore.shortcut
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
                      hotKeyID.signature == OSType(0x414B5052),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<AutoKeyPressController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.toggleFromShortcut()
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

    private func toggleFromShortcut() {
        if isRunning {
            stopRepeating()
        } else if AutoKeyPressStore.hasTargetKey {
            startRepeating()
        } else {
            configureAndStart()
        }
    }

    private func startRepeating() {
        guard AutoKeyPressStore.isEnabled else {
            lastStatus = "Setting is off"
            return
        }
        guard let keyCode = AutoKeyPressStore.targetKeyCode else {
            configureAndStart()
            return
        }

        timer?.invalidate()
        let interval = AutoKeyPressStore.interval
        press(keyCode)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Self.pressKey(keyCode)
        }
        timer?.tolerance = min(0.08, interval * 0.1)
        isRunning = true
        lastStatus = "Firing \(AutoKeyPressStore.targetKeyName) every \(Self.intervalText(interval))"
    }

    private func press(_ keyCode: UInt16) {
        Self.pressKey(keyCode)
    }

    private nonisolated static func pressKey(_ keyCode: UInt16) {
        let source = CGEventSource(stateID: .hidSystemState)
        let key = CGKeyCode(keyCode)

        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func intervalText(_ interval: TimeInterval) -> String {
        interval == floor(interval) ? "\(Int(interval))s" : String(format: "%.1fs", interval)
    }
}
