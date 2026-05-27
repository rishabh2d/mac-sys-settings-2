//
//  LoginItemStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation
import ServiceManagement

enum LoginItemStore {
    static let didChangeNotification = Notification.Name("LoginItemStoreDidChange")
    private static let userChoiceKey = "app.launchAtLogin.userChoice.v1"

    static var hasUserChoice: Bool {
        UserDefaults.standard.object(forKey: userChoiceKey) != nil
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool, rememberChoice: Bool = true) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
            return isEnabled
        }

        if rememberChoice {
            UserDefaults.standard.set(enabled, forKey: userChoiceKey)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return isEnabled
    }

    static func enableByDefaultIfNeeded() {
        guard !hasUserChoice else { return }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
