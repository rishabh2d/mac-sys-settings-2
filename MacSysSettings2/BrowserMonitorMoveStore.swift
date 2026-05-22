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

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
