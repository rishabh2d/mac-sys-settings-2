//
//  AutoKeyPressSetupPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/23/26.
//

import AppKit
import Carbon
import SwiftUI

@MainActor
final class AutoKeyPressSetupPresenter {
    struct Result {
        let keyCode: UInt16
        let keyName: String
        let interval: TimeInterval
    }

    private enum Stage {
        case key
        case interval(UInt16, String)
    }

    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var stage: Stage = .key
    private var completion: ((Result?) -> Void)?

    func show(completion: @escaping (Result?) -> Void) {
        close(complete: false)
        self.completion = completion
        stage = .key
        showPanel(title: "Press key to repeat", subtitle: "Press the key that should auto-fire. Esc cancels.")
        installMonitors()
    }

    private func installMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            close(complete: false)
            return
        }

        switch stage {
        case .key:
            guard let keyName = Self.keyName(for: event) else { return }
            stage = .interval(event.keyCode, keyName)
            showPanel(title: "Press interval number", subtitle: "\(keyName) will fire every N seconds. Press numpad 1-9, or 0 for 10 seconds.")
        case let .interval(keyCode, keyName):
            guard let seconds = Self.intervalSeconds(for: event) else { return }
            let result = Result(keyCode: keyCode, keyName: keyName, interval: seconds)
            close(complete: true, result: result)
        }
    }

    private func showPanel(title: String, subtitle: String) {
        let root = AutoKeyPressSetupView(title: title, subtitle: subtitle)

        if let panel {
            panel.contentView = NSHostingView(rootView: root)
            return
        }

        let size = NSSize(width: 430, height: 166)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: root)

        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            ))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func close(complete: Bool, result: Result? = nil) {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        panel?.orderOut(nil)
        panel = nil

        let completion = self.completion
        self.completion = nil
        if complete {
            completion?(result)
        } else {
            completion?(nil)
        }
    }

    private static func intervalSeconds(for event: NSEvent) -> TimeInterval? {
        switch Int(event.keyCode) {
        case kVK_ANSI_1, kVK_ANSI_Keypad1: return 1
        case kVK_ANSI_2, kVK_ANSI_Keypad2: return 2
        case kVK_ANSI_3, kVK_ANSI_Keypad3: return 3
        case kVK_ANSI_4, kVK_ANSI_Keypad4: return 4
        case kVK_ANSI_5, kVK_ANSI_Keypad5: return 5
        case kVK_ANSI_6, kVK_ANSI_Keypad6: return 6
        case kVK_ANSI_7, kVK_ANSI_Keypad7: return 7
        case kVK_ANSI_8, kVK_ANSI_Keypad8: return 8
        case kVK_ANSI_9, kVK_ANSI_Keypad9: return 9
        case kVK_ANSI_0, kVK_ANSI_Keypad0: return 10
        default: return nil
        }
    }

    private static func keyName(for event: NSEvent) -> String? {
        if let character = event.charactersIgnoringModifiers?.uppercased(), character.count == 1 {
            return character
        }

        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_LeftArrow: return "Left"
        case kVK_RightArrow: return "Right"
        case kVK_UpArrow: return "Up"
        case kVK_DownArrow: return "Down"
        default: return nil
        }
    }
}

private struct AutoKeyPressSetupView: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 430, height: 166)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}
