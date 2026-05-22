//
//  MonitorMoveOthersShortcutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum MonitorMoveOthersShortcutStore {
    static let didChangeNotification = Notification.Name("MonitorMoveOthersShortcutDidChange")
    private nonisolated static let defaultsKey = "screen.monitorMoveOthersShortcut.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
