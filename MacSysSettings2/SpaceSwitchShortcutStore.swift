//
//  SpaceSwitchShortcutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum SpaceSwitchShortcutStore {
    private static let domain = "com.apple.symbolichotkeys"
    private static let managedHotKeys: [String: [Int]] = [
        "32": [65535, 126, 262144],
        "79": [65535, 123, 262144],
        "80": [65535, 124, 262144]
    ]

    static var isEnabled: Bool {
        managedHotKeys.keys.contains { isHotKeyEnabled($0) }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let defaults = UserDefaults.standard
        var domainValues = defaults.persistentDomain(forName: domain) ?? [:]
        var hotKeys = domainValues["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]

        for (id, parameters) in managedHotKeys {
            var entry = hotKeys[id] as? [String: Any] ?? [:]
            entry["enabled"] = enabled
            if entry["value"] == nil {
                entry["value"] = [
                    "parameters": parameters,
                    "type": "standard"
                ]
            }
            hotKeys[id] = entry
        }

        domainValues["AppleSymbolicHotKeys"] = hotKeys
        defaults.setPersistentDomain(domainValues, forName: domain)
        defaults.synchronize()
        restartDockForShortcutRefresh()
        return isEnabled == enabled
    }

    private static func isHotKeyEnabled(_ id: String) -> Bool {
        let domainValues = UserDefaults.standard.persistentDomain(forName: domain)
        let hotKeys = domainValues?["AppleSymbolicHotKeys"] as? [String: Any]
        let entry = hotKeys?[id] as? [String: Any]

        if let enabled = entry?["enabled"] as? Bool {
            return enabled
        }

        if let enabled = entry?["enabled"] as? Int {
            return enabled != 0
        }

        return false
    }

    private static func restartDockForShortcutRefresh() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }
}
