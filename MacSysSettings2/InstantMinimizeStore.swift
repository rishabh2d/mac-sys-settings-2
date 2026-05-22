//
//  InstantMinimizeStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum InstantMinimizeStore {
    static let didChangeNotification = Notification.Name("InstantMinimizeDidChange")

    private nonisolated static let enabledKey = "dock.instantCommandM.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
