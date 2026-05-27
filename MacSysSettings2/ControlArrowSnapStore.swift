//
//  ControlArrowSnapStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum ControlArrowSnapStore {
    static let didChangeNotification = Notification.Name("ControlArrowSnapDidChange")
    private nonisolated static let defaultsKey = "screen.controlArrowSnap.enabled"
    private nonisolated static let snapAfterMonitorDragKey = "screen.controlArrowSnap.snapAfterMonitorDrag"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        if enabled {
            SpaceSwitchShortcutStore.setEnabled(false)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    nonisolated static var snapAfterMonitorDragEnabled: Bool {
        UserDefaults.standard.object(forKey: snapAfterMonitorDragKey) as? Bool ?? false
    }

    static func setSnapAfterMonitorDragEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: snapAfterMonitorDragKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
