//
//  PinWindowStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/24/26.
//

import Carbon
import Foundation

enum PinWindowStore {
    static let didChangeNotification = Notification.Name("PinWindowDidChange")

    private nonisolated static let enabledKey = "screen.pinWindow.enabled"

    static let shortcut = ScreenShortcut(
        keyCode: UInt32(kVK_ANSI_P),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        parts: ["Control", "Option", "Command", "P"]
    )

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
