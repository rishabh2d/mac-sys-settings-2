//
//  CommandHideToggleStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum CommandHideToggleStore {
    static let didChangeNotification = Notification.Name("CommandHideToggleDidChange")
    private nonisolated static let defaultsKey = "screen.commandHideToggle.enabled"
    private nonisolated static let focusedWindowOnlyKey = "screen.commandHideToggle.focusedWindowOnly"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    nonisolated static var hidesFocusedWindowOnly: Bool {
        UserDefaults.standard.object(forKey: focusedWindowOnlyKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func setHidesFocusedWindowOnly(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: focusedWindowOnlyKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
