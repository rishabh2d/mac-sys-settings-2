//
//  AutoScrollStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum AutoScrollStore {
    static let didChangeNotification = Notification.Name("AutoScrollDidChange")
    private nonisolated static let enabledKey = "screen.autoScroll.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
