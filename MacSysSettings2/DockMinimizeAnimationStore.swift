//
//  DockMinimizeAnimationStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import Foundation

enum DockMinimizeAnimationStore {
    static let didChangeNotification = Notification.Name("DockMinimizeAnimationDidChange")

    private nonisolated static let enabledKey = "dock.minimizeAnimation.fastScale.enabled"
    private nonisolated static let previousEffectKey = "dock.minimizeAnimation.previousEffect"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    nonisolated static var currentEffect: String {
        readDockEffect() ?? "genie"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            if UserDefaults.standard.string(forKey: previousEffectKey) == nil,
               let current = readDockEffect(),
               current != "scale" {
                UserDefaults.standard.set(current, forKey: previousEffectKey)
            }

            guard writeDockEffect("scale") else { return false }
        } else {
            let restoreEffect = UserDefaults.standard.string(forKey: previousEffectKey) ?? "genie"
            guard writeDockEffect(restoreEffect) else { return false }
        }

        UserDefaults.standard.set(enabled, forKey: enabledKey)
        restartDock()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return true
    }

    nonisolated private static func readDockEffect() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.dock", "mineffect"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func writeDockEffect(_ effect: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.dock", "mineffect", "-string", effect]

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
