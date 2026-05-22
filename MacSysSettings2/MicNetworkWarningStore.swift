//
//  MicNetworkWarningStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import Foundation

enum MicNetworkWarningStore {
    static let didChangeNotification = Notification.Name("MicNetworkWarningDidChange")
    private nonisolated static let enabledKey = "mic.network.warning.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
