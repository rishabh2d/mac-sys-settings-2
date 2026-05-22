//
//  MonitorMoveShortcutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum MonitorMoveShortcutStore {
    static let didChangeNotification = Notification.Name("MonitorMoveShortcutDidChange")
    private nonisolated static let defaultsKey = "screen.monitorMoveShortcut.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
