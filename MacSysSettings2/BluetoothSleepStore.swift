//
//  BluetoothSleepStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import Foundation

enum BluetoothSleepStore {
    static let didChangeNotification = Notification.Name("BluetoothSleepStoreDidChange")

    private nonisolated static let enabledKey = "bluetooth.sleep.enabled"
    private nonisolated static let batteryOnlyKey = "bluetooth.sleep.batteryOnly"
    private nonisolated static let turnedOffByAppKey = "bluetooth.sleep.turnedOffByApp"
    private nonisolated static let lastStatusKey = "bluetooth.sleep.lastStatus"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    nonisolated static var onlyOnBattery: Bool {
        UserDefaults.standard.object(forKey: batteryOnlyKey) as? Bool ?? false
    }

    nonisolated static var turnedOffByApp: Bool {
        UserDefaults.standard.bool(forKey: turnedOffByAppKey)
    }

    nonisolated static var lastStatus: String {
        UserDefaults.standard.string(forKey: lastStatusKey) ?? "Off"
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        notifyChanged()
    }

    static func setOnlyOnBattery(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: batteryOnlyKey)
        notifyChanged()
    }

    static func setTurnedOffByApp(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: turnedOffByAppKey)
    }

    static func setLastStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: lastStatusKey)
        notifyChanged()
    }

    private static func notifyChanged() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
