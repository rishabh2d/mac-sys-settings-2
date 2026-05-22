//
//  BluetoothAudioInputPromptStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum BluetoothAudioInputPromptStore {
    static let didChangeNotification = Notification.Name("BluetoothAudioInputPromptDidChange")
    private nonisolated static let enabledKey = "bluetooth.audio.input.prompt.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
