//
//  DockRevealStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum DockRevealStore {
    static let didChangeNotification = Notification.Name("DockRevealDidChange")

    private nonisolated static let enabledKey = "dock.reveal.instant.enabled"
    private nonisolated static let delayDefaultsKey = "autohide-delay"
    private nonisolated static let animationDefaultsKey = "autohide-time-modifier"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    nonisolated static var statusText: String {
        guard isEnabled else { return "Default" }
        return "Instant"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let ok: Bool
        if enabled {
            ok = writeDockNumber(key: delayDefaultsKey, value: "0")
                && writeDockNumber(key: animationDefaultsKey, value: "0.12")
        } else {
            ok = deleteDockKey(delayDefaultsKey)
                && deleteDockKey(animationDefaultsKey)
        }

        guard ok else { return false }
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        restartDock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return true
    }

    @discardableResult
    static func restoreDefaults() -> Bool {
        let ok = deleteDockKey(delayDefaultsKey) && deleteDockKey(animationDefaultsKey)
        guard ok else { return false }
        UserDefaults.standard.set(false, forKey: enabledKey)
        restartDock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return true
    }

    private static func writeDockNumber(key: String, value: String) -> Bool {
        runDefaults(arguments: ["write", "com.apple.dock", key, "-float", value])
    }

    private static func deleteDockKey(_ key: String) -> Bool {
        if runDefaults(arguments: ["delete", "com.apple.dock", key]) {
            return true
        }

        return true
    }

    private static func runDefaults(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }
}
