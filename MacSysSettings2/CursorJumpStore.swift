//
//  CursorJumpStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation
import Carbon

enum CursorJumpStore {
    static let didChangeNotification = Notification.Name("CursorJumpDidChange")
    private nonisolated static let enabledKey = "screen.cursorJump.enabled"
    private nonisolated static let shortcutKey = "screen.cursorJump.shortcut.v1"
    static let defaultShortcut = ScreenShortcut(
        keyCode: UInt32(kVK_F2),
        carbonModifiers: UInt32(cmdKey),
        parts: ["Command", "F2"]
    )

    nonisolated static var shortcutText: String {
        currentShortcut().displayText
    }

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    nonisolated static func currentShortcut() -> ScreenShortcut {
        ScreenShortcut.from(
            dictionary: UserDefaults.standard.dictionary(forKey: shortcutKey),
            fallback: defaultShortcut
        )
    }

    static func saveShortcut(_ shortcut: ScreenShortcut) {
        UserDefaults.standard.set(shortcut.dictionaryValue(), forKey: shortcutKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func resetShortcut() {
        UserDefaults.standard.removeObject(forKey: shortcutKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
