//
//  FullscreenEscapeController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class FullscreenEscapeController: ObservableObject {
    @Published private(set) var lastStatus = "Command-Option-Tab is ready."

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x46534532), id: 100)

    func start() {
        observeChanges()
        registerHotKey()
    }

    private func observeChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: FullscreenEscapeStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.unregisterHotKey()
                self.registerHotKey()
            }
        }
    }

    private func registerHotKey() {
        guard FullscreenEscapeStore.isEnabled, hotKeyRef == nil else { return }
        guard installHandlerIfNeeded() else {
            lastStatus = "Could not install Command-Option-Tab."
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        lastStatus = status == noErr ? "Command-Option-Tab is ready." : "Command-Option-Tab could not register."
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() -> Bool {
        guard eventHandlerRef == nil else { return true }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let controller = Unmanaged<FullscreenEscapeController>
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
        guard id == hotKeyID.id else { return }
        focusNextFullscreenWindow()
    }

    private func focusNextFullscreenWindow() {
        guard AXIsProcessTrusted() else {
            lastStatus = "Accessibility permission is required."
            return
        }

        let windows = fullscreenWindows()
        guard !windows.isEmpty else {
            lastStatus = "No fullscreen windows found."
            return
        }

        let focusedPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let nextIndex: Int
        if let focusedPID,
           let currentIndex = windows.firstIndex(where: { $0.pid == focusedPID && $0.isFocused }) {
            nextIndex = windows.index(after: currentIndex) == windows.endIndex ? windows.startIndex : windows.index(after: currentIndex)
        } else if let focusedPID,
                  let currentIndex = windows.firstIndex(where: { $0.pid == focusedPID }) {
            nextIndex = windows.index(after: currentIndex) == windows.endIndex ? windows.startIndex : windows.index(after: currentIndex)
        } else {
            nextIndex = windows.startIndex
        }

        let target = windows[nextIndex]
        target.app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(target.window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(target.appElement, kAXFocusedWindowAttribute as CFString, target.window)
        lastStatus = "Switched to \(target.app.localizedName ?? "fullscreen window")."
    }

    private func fullscreenWindows() -> [FullscreenWindow] {
        var results: [FullscreenWindow] = []

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = attribute(kAXWindowsAttribute as CFString, on: appElement) as? [AXUIElement] else {
                continue
            }

            let focusedWindow = attribute(kAXFocusedWindowAttribute as CFString, on: appElement)
            for window in windows {
                guard (attribute("AXFullScreen" as CFString, on: window) as? Bool) == true else {
                    continue
                }

                let focused = focusedWindow.map { CFEqual($0 as CFTypeRef, window) } ?? false
                results.append(FullscreenWindow(app: app, appElement: appElement, window: window, pid: app.processIdentifier, isFocused: focused))
            }
        }

        return results
    }

    private func attribute(_ name: CFString, on element: AXUIElement) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
            return nil
        }
        return value
    }
}

private struct FullscreenWindow {
    let app: NSRunningApplication
    let appElement: AXUIElement
    let window: AXUIElement
    let pid: pid_t
    let isFocused: Bool
}
