//
//  BatteryMenuStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum BatteryMenuStore {
    static let didChangeNotification = Notification.Name("BatteryMenuStoreDidChange")

    private nonisolated static let hideNativeBatteryKey = "batteryMenu.hideNativeBatteryIcon"

    static var hidesNativeBatteryIcon: Bool {
        if UserDefaults.standard.object(forKey: hideNativeBatteryKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: hideNativeBatteryKey)
    }

    @discardableResult
    static func setHidesNativeBatteryIcon(_ enabled: Bool) -> Bool {
        UserDefaults.standard.set(enabled, forKey: hideNativeBatteryKey)
        applyNativeBatteryVisibility()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return enabled
    }

    static func applyNativeBatteryVisibility() {
        let shouldHide = hidesNativeBatteryIcon
        _ = runDefaults(arguments: ["write", "com.apple.controlcenter", "NSStatusItem VisibleCC Battery", "-bool", shouldHide ? "false" : "true"])
        _ = runDefaults(arguments: ["write", "com.apple.controlcenter", "NSStatusItem Visible Battery", "-bool", shouldHide ? "false" : "true"])
        _ = runDefaults(arguments: ["-currentHost", "write", "com.apple.controlcenter", "Battery", "-int", shouldHide ? "8" : "18"])
        restartControlCenter()
    }

    private static func runDefaults(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func restartControlCenter() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["ControlCenter"]
        try? process.run()
    }
}
