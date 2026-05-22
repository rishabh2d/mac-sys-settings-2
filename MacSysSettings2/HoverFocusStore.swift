//
//  HoverFocusStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import Foundation

enum HoverFocusStore {
    static let didChangeNotification = Notification.Name("HoverFocusDidChange")
    private nonisolated static let defaultsKey = "screen.hoverFocus.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
