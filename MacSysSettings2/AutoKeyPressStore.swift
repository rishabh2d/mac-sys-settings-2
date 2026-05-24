//
//  AutoKeyPressStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/23/26.
//

import Carbon
import Foundation

enum AutoKeyPressStore {
    static let didChangeNotification = Notification.Name("AutoKeyPressDidChange")

    private nonisolated static let enabledKey = "autoKeyPress.enabled"
    private nonisolated static let shortcutKey = "autoKeyPress.shortcut.v1"
    private nonisolated static let targetKeyCodeKey = "autoKeyPress.targetKeyCode"
    private nonisolated static let targetKeyNameKey = "autoKeyPress.targetKeyName"
    private nonisolated static let intervalKey = "autoKeyPress.interval"

    static let defaultShortcut = ScreenShortcut(
        keyCode: UInt32(kVK_ANSI_K),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        parts: ["Control", "Option", "Command", "K"]
    )

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    nonisolated static var targetKeyCode: UInt16? {
        let value = UserDefaults.standard.integer(forKey: targetKeyCodeKey)
        return UserDefaults.standard.object(forKey: targetKeyCodeKey) == nil ? nil : UInt16(value)
    }

    nonisolated static var targetKeyName: String {
        UserDefaults.standard.string(forKey: targetKeyNameKey) ?? "Not set"
    }

    nonisolated static var interval: TimeInterval {
        let value = UserDefaults.standard.double(forKey: intervalKey)
        return value > 0 ? value : 1
    }

    nonisolated static var hasTargetKey: Bool {
        targetKeyCode != nil
    }

    nonisolated static var shortcut: ScreenShortcut {
        ScreenShortcut.from(
            dictionary: UserDefaults.standard.dictionary(forKey: shortcutKey),
            fallback: defaultShortcut
        )
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func saveShortcut(_ shortcut: ScreenShortcut) {
        UserDefaults.standard.set(shortcut.dictionaryValue(), forKey: shortcutKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func saveTargetKey(keyCode: UInt16, name: String) {
        UserDefaults.standard.set(Int(keyCode), forKey: targetKeyCodeKey)
        UserDefaults.standard.set(name, forKey: targetKeyNameKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func saveInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(max(0.1, interval), forKey: intervalKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func clearTargetKey() {
        UserDefaults.standard.removeObject(forKey: targetKeyCodeKey)
        UserDefaults.standard.removeObject(forKey: targetKeyNameKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
