//
//  DockHiddenAppsStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum DockHiddenAppsStore {
    static let didChangeNotification = Notification.Name("DockHiddenAppsDidChange")

    private nonisolated static let enabledKey = "dock.hiddenApps.dimIndicator.enabled"
    private nonisolated static let dockDefaultsKey = "showhidden"

    nonisolated static var isEnabled: Bool {
        readDockBool() ?? UserDefaults.standard.bool(forKey: enabledKey)
    }

    nonisolated static var statusText: String {
        isEnabled ? "Dimmed" : "Default"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let ok = writeDockBool(enabled)
        guard ok else { return false }

        UserDefaults.standard.set(enabled, forKey: enabledKey)
        restartDock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return true
    }

    nonisolated private static func readDockBool() -> Bool? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.dock", dockDefaultsKey]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let value = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return value == "1" || value == "true" || value == "yes"
    }

    private static func writeDockBool(_ enabled: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.dock", dockDefaultsKey, "-bool", enabled ? "true" : "false"]

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
