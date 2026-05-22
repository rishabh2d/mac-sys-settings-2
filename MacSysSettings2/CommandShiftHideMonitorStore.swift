//
//  CommandShiftHideMonitorStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum CommandShiftHideMonitorStore {
    static let didChangeNotification = Notification.Name("CommandShiftHideMonitorDidChange")
    private nonisolated static let defaultsKey = "screen.commandShiftHideMonitor.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
