//
//  ControlArrowSnapStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum ControlArrowSnapStore {
    static let didChangeNotification = Notification.Name("ControlArrowSnapDidChange")
    private static let defaultsKey = "screen.controlArrowSnap.enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        if enabled {
            SpaceSwitchShortcutStore.setEnabled(false)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
