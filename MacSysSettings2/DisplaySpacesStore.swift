//
//  DisplaySpacesStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import Foundation

enum DisplaySpacesStore {
    static let didChangeNotification = Notification.Name("DisplaySpacesDidChange")
    private static let domain = "com.apple.spaces"
    private static let spansDisplaysKey = "spans-displays"

    static var missionControlFocusedDisplayOnly: Bool {
        spansDisplays == false
    }

    @discardableResult
    static func setMissionControlFocusedDisplayOnly(_ enabled: Bool) -> Bool {
        let defaults = UserDefaults.standard
        var domainValues = defaults.persistentDomain(forName: domain) ?? [:]
        domainValues[spansDisplaysKey] = !enabled
        defaults.setPersistentDomain(domainValues, forName: domain)
        defaults.synchronize()
        writeCurrentHostValue(enabled: enabled)
        restartDesktopServices()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return missionControlFocusedDisplayOnly == enabled
    }

    private static var spansDisplays: Bool {
        let value = UserDefaults.standard.persistentDomain(forName: domain)?[spansDisplaysKey]

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let intValue = value as? Int {
            return intValue != 0
        }

        return false
    }

    private static func writeCurrentHostValue(enabled: Bool) {
        run("/usr/bin/defaults", arguments: [
            "-currentHost",
            "write",
            domain,
            spansDisplaysKey,
            "-bool",
            enabled ? "false" : "true"
        ])
    }

    private static func restartDesktopServices() {
        run("/usr/bin/killall", arguments: ["cfprefsd"])
        run("/usr/bin/killall", arguments: ["Dock"])
        run("/usr/bin/killall", arguments: ["SystemUIServer"])
    }

    private static func run(_ path: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }
}
