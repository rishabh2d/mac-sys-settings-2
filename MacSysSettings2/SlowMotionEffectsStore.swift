//
//  SlowMotionEffectsStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import Foundation

enum SlowMotionEffectsStore {
    static let didChangeNotification = Notification.Name("SlowMotionEffectsDidChange")

    nonisolated static var isEnabled: Bool {
        let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.dock", "slow-motion-allowed"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return output == "1" || output == "true" || output == "yes"
    }

    nonisolated static var statusText: String {
        isEnabled ? "On" : "Off"
    }

    static func setEnabled(_ enabled: Bool) {
        _ = runCommand(
            "/usr/bin/defaults",
            arguments: ["write", "com.apple.dock", "slow-motion-allowed", "-bool", enabled ? "true" : "false"]
        )
        restartDock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private nonisolated static func restartDock() {
        _ = runCommand("/usr/bin/killall", arguments: ["Dock"])
    }

    @discardableResult
    private nonisolated static func runCommand(_ path: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
