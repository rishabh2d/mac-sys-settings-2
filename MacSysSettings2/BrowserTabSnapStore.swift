//
//  BrowserTabSnapStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum BrowserTabSnapStore {
    static let didChangeNotification = Notification.Name("BrowserTabSnapDidChange")
    private nonisolated static let defaultsKey = "screen.browserTabSnap.enabled"
    private nonisolated static let quickPairDefaultsKey = "screen.browserTabSnap.quickPair.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    nonisolated static var quickOppositeArrowEnabled: Bool {
        UserDefaults.standard.object(forKey: quickPairDefaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func setQuickOppositeArrowEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: quickPairDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
