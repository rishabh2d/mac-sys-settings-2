//
//  BrowserMonitorMoveStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum BrowserMonitorMoveStore {
    static let didChangeNotification = Notification.Name("BrowserMonitorMoveDidChange")
    private nonisolated static let defaultsKey = "screen.browserMonitorMove.choice.enabled"
    private nonisolated static let fastShortcutsDefaultsKey = "screen.browserMonitorMove.fastShortcuts.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    nonisolated static var fastShortcutsEnabled: Bool {
        UserDefaults.standard.object(forKey: fastShortcutsDefaultsKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func setFastShortcutsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: fastShortcutsDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
