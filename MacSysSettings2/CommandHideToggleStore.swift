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

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
