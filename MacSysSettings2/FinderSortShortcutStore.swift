//
//  FinderSortShortcutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum FinderSortShortcutStore {
    static let didChangeNotification = Notification.Name("FinderSortShortcutDidChange")
    private nonisolated static let defaultsKey = "finder.sortShortcut.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
