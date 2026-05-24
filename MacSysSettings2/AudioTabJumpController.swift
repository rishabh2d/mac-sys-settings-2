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
        let window: AXUIElement
        let tabButton: AXUIElement
    }

    @Published private(set) var lastStatus = "Ready"

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
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
    }

    func jumpToPlayingTab() {
        guard AXIsProcessTrusted() else {
            lastStatus = "Allow Accessibility"
            return
        }

        for bundleID in browserBundleIDs {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
                  let match = firstAudioTab(in: app.processIdentifier) else {
                continue
            }

            setBoolAttribute(kAXMinimizedAttribute, on: match.window, value: false)
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            AXUIElementSetAttributeValue(match.window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(match.window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(match.window, kAXRaiseAction as CFString)
            AXUIElementPerformAction(match.tabButton, kAXPressAction as CFString)
            lastStatus = "Opened audio tab"
            return
        }

        lastStatus = "No audio tab found"
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
        registerHotKey()
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
                    controller.jumpToPlayingTab()
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

    private func firstAudioTab(in pid: pid_t) -> AudioTabMatch? {
        let appElement = AXUIElementCreateApplication(pid)
        for window in windows(of: appElement) {
            if let tabButton = firstAudioTabButton(in: window, depth: 0) {
                return AudioTabMatch(window: window, tabButton: tabButton)
            }
        }

        return nil
    }

    private func firstAudioTabButton(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 12 else { return nil }

        if role(of: element) == kAXRadioButtonRole as String,
           elementLooksLikePlayingTab(element) {
            return element
        }

        for child in children(of: element) {
            if let match = firstAudioTabButton(in: child, depth: depth + 1) {
                return match
            }
        }

        return nil
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
}
