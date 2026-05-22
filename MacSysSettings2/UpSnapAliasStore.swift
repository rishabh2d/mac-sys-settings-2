//
//  UpSnapAliasStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum UpSnapAliasStore {
    static let didChangeNotification = Notification.Name("UpSnapAliasDidChange")
    private nonisolated static let optionUpKey = "screen.upSnapAlias.optionUp.enabled"
    private nonisolated static let commandUpKey = "screen.upSnapAlias.commandUp.enabled"

    nonisolated static var optionUpEnabled: Bool {
        UserDefaults.standard.object(forKey: optionUpKey) as? Bool ?? true
    }

    nonisolated static var commandUpEnabled: Bool {
        UserDefaults.standard.object(forKey: commandUpKey) as? Bool ?? true
    }

    static func setOptionUpEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: optionUpKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func setCommandUpEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: commandUpKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
