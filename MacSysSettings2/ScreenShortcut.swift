//
//  ScreenShortcut.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import Carbon
import Foundation

struct ScreenShortcut: Equatable {
    static let defaultsKey = "screen.move.shortcut.v1"
    static let didChangeNotification = Notification.Name("ScreenShortcutDidChange")

    var keyCode: UInt32
    var carbonModifiers: UInt32
    var parts: [String]

    static let defaultShortcut = ScreenShortcut(
        keyCode: UInt32(kVK_RightArrow),
        carbonModifiers: UInt32(controlKey | optionKey),
        parts: ["Control", "Option", "Left/Right"]
    )

    var displayText: String {
        parts.joined(separator: "-")
    }

    var isUsable: Bool {
        parts.count >= 2 && parts.count <= 3 && carbonModifiers != 0
    }

    static func current() -> ScreenShortcut {
        guard let data = UserDefaults.standard.dictionary(forKey: defaultsKey),
              let keyCode = data["keyCode"] as? Int,
              let modifiers = data["carbonModifiers"] as? Int,
              let parts = data["parts"] as? [String],
              parts.count >= 2 else {
            return defaultShortcut
        }

        if keyCode == kVK_ANSI_Q && modifiers == controlKey {
            return defaultShortcut
        }

        return ScreenShortcut(keyCode: UInt32(keyCode), carbonModifiers: UInt32(modifiers), parts: parts)
    }

    func save() {
        UserDefaults.standard.set(
            [
                "keyCode": Int(keyCode),
                "carbonModifiers": Int(carbonModifiers),
                "parts": parts
            ],
            forKey: Self.defaultsKey
        )
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    var pairedMoveKeyCode: UInt32? {
        guard carbonModifiers == UInt32(controlKey | optionKey) else { return nil }

        if keyCode == UInt32(kVK_LeftArrow) {
            return UInt32(kVK_RightArrow)
        }

        if keyCode == UInt32(kVK_RightArrow) {
            return UInt32(kVK_LeftArrow)
        }

        return nil
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func from(event: NSEvent) -> ScreenShortcut? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts: [String] = []
        var carbonModifiers: UInt32 = 0

        if modifiers.contains(.control) {
            parts.append("Control")
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers.contains(.option) {
            parts.append("Option")
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            parts.append("Shift")
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers.contains(.command) {
            parts.append("Command")
            carbonModifiers |= UInt32(cmdKey)
        }

        guard parts.count == 1 || parts.count == 2 else { return nil }
        guard let keyName = keyName(for: event) else { return nil }

        parts.append(keyName)
        return ScreenShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers, parts: parts)
    }

    private static func keyName(for event: NSEvent) -> String? {
        if let character = event.charactersIgnoringModifiers?.uppercased(), character.count == 1 {
            return character
        }

        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Forward Delete"
        case kVK_LeftArrow: return "Left"
        case kVK_RightArrow: return "Right"
        case kVK_UpArrow: return "Up"
        case kVK_DownArrow: return "Down"
        default: return nil
        }
    }
}
