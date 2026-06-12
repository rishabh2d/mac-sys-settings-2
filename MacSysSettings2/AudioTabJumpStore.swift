//
//  AudioTabJumpStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/24/26.
//

import Carbon
import Foundation

enum AudioTabJumpStore {
    static let didChangeNotification = Notification.Name("AudioTabJumpDidChange")

    private nonisolated static let enabledKey = "audioTabJump.enabled"
    private nonisolated static let shortcutKey = "audioTabJump.shortcut.v1"

    static let defaultShortcut = ScreenShortcut(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(controlKey | optionKey),
        parts: ["Control", "Option", "P"]
    )

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    nonisolated static var shortcut: ScreenShortcut {
        let saved = ScreenShortcut.from(
            dictionary: UserDefaults.standard.dictionary(forKey: shortcutKey),
            fallback: defaultShortcut
        )
        if saved.keyCode == UInt32(kVK_ANSI_P),
           saved.carbonModifiers == UInt32(controlKey | optionKey | cmdKey) {
            return defaultShortcut
        }
        return saved
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func saveShortcut(_ shortcut: ScreenShortcut) {
        UserDefaults.standard.set(shortcut.dictionaryValue(), forKey: shortcutKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
