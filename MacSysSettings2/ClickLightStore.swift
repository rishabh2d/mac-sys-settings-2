//
//  ClickLightStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/25/26.
//

import Foundation

enum ClickLightStore {
    static let didChangeNotification = Notification.Name("ClickLightStoreDidChange")

    private nonisolated static let enabledKey = "presentation.clickLight.enabled"
    private nonisolated static let sizeKey = "presentation.clickLight.size"
    private nonisolated static let durationKey = "presentation.clickLight.duration"
    private nonisolated static let intensityKey = "presentation.clickLight.intensity"

    nonisolated static var isEnabled: Bool {
        guard UserDefaults.standard.object(forKey: enabledKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    nonisolated static var size: Double {
        let stored = UserDefaults.standard.double(forKey: sizeKey)
        return stored == 0 ? 52 : stored
    }

    nonisolated static var duration: Double {
        let stored = UserDefaults.standard.double(forKey: durationKey)
        return stored == 0 ? 0.45 : stored
    }

    nonisolated static var intensity: Double {
        let stored = UserDefaults.standard.double(forKey: intensityKey)
        return stored == 0 ? 0.75 : stored
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        notify()
    }

    static func setSize(_ size: Double) {
        UserDefaults.standard.set(size, forKey: sizeKey)
        notify()
    }

    static func setDuration(_ duration: Double) {
        UserDefaults.standard.set(duration, forKey: durationKey)
        notify()
    }

    static func setIntensity(_ intensity: Double) {
        UserDefaults.standard.set(intensity, forKey: intensityKey)
        notify()
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
