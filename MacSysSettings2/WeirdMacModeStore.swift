//
//  WeirdMacModeStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Carbon
import Foundation

enum WeirdMacModeStore {
    enum Fix: String, CaseIterable, Identifiable {
        case stuckModifiers
        case voiceOver
        case stickyKeys
        case slowKeys
        case mouseKeys
        case fullKeyboardAccess
        case reduceMotion
        case invertColors
        case zoom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stuckModifiers: return "Stuck modifier keys"
            case .voiceOver: return "VoiceOver"
            case .stickyKeys: return "Sticky Keys"
            case .slowKeys: return "Slow Keys"
            case .mouseKeys: return "Mouse Keys"
            case .fullKeyboardAccess: return "Keyboard focus boxes"
            case .reduceMotion: return "Reduce Motion"
            case .invertColors: return "Invert Colors"
            case .zoom: return "Screen Zoom"
            }
        }

        var subtitle: String {
            switch self {
            case .stuckModifiers:
                return "If typing/clicking fires random shortcuts, release stuck Option, Control, Shift, Command, and Fn."
            case .voiceOver:
                return "If clicks select items with a spoken outline and normal clicking feels broken, VoiceOver may be on."
            case .stickyKeys:
                return "If modifier keys stay active after one tap, turn off Sticky Keys."
            case .slowKeys:
                return "If typing only works after holding each key, turn off Slow Keys."
            case .mouseKeys:
                return "If keyboard keys move the pointer instead of typing, turn off Mouse Keys."
            case .fullKeyboardAccess:
                return "If blue focus rings jump through every control, restore normal keyboard focus behavior."
            case .reduceMotion:
                return "If animations feel unexpectedly flat or weird, turn off Reduce Motion."
            case .invertColors:
                return "If the whole screen color scheme looks inverted, turn off color inversion."
            case .zoom:
                return "If the screen is stuck zoomed in or follows the cursor strangely, turn off system zoom."
            }
        }

        var settingsURL: String {
            switch self {
            case .stuckModifiers:
                return "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
            case .voiceOver:
                return "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"
            case .stickyKeys, .slowKeys, .mouseKeys, .fullKeyboardAccess:
                return "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
            case .reduceMotion, .invertColors, .zoom:
                return "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"
            }
        }
    }

    static func status(for fix: Fix) -> String {
        switch fix {
        case .stuckModifiers:
            return "Reset"
        case .voiceOver:
            return voiceOverIsRunning ? "May be on" : "Looks off"
        case .stickyKeys:
            return defaultsBool(domain: "com.apple.universalaccess", key: "stickyKey") ? "On" : "Off"
        case .slowKeys:
            return defaultsBool(domain: "com.apple.universalaccess", key: "slowKey") ? "On" : "Off"
        case .mouseKeys:
            return defaultsBool(domain: "com.apple.universalaccess", key: "mouseDriver") ? "On" : "Off"
        case .fullKeyboardAccess:
            return defaultsInt(domain: "NSGlobalDomain", key: "AppleKeyboardUIMode") >= 2 ? "All controls" : "Normal"
        case .reduceMotion:
            return defaultsBool(domain: "com.apple.universalaccess", key: "reduceMotion") ? "On" : "Off"
        case .invertColors:
            return defaultsBool(domain: "com.apple.universalaccess", key: "invertColors") ? "On" : "Off"
        case .zoom:
            return defaultsBool(domain: "com.apple.universalaccess", key: "closeViewHotkeysEnabled")
                || defaultsBool(domain: "com.apple.universalaccess", key: "closeViewScrollWheelToggle") ? "May be on" : "Looks off"
        }
    }

    static func fix(_ fix: Fix) -> String {
        switch fix {
        case .stuckModifiers:
            ModifierKeySafety.releaseShortcutModifiers()
            return "Released"
        case .voiceOver:
            stopVoiceOver()
            return voiceOverIsRunning ? "Opened pane" : "Stopped"
        case .stickyKeys:
            writeBool(domain: "com.apple.universalaccess", key: "stickyKey", value: false)
            return "Off"
        case .slowKeys:
            writeBool(domain: "com.apple.universalaccess", key: "slowKey", value: false)
            return "Off"
        case .mouseKeys:
            writeBool(domain: "com.apple.universalaccess", key: "mouseDriver", value: false)
            return "Off"
        case .fullKeyboardAccess:
            writeInt(domain: "NSGlobalDomain", key: "AppleKeyboardUIMode", value: 0)
            return "Normal"
        case .reduceMotion:
            writeBool(domain: "com.apple.universalaccess", key: "reduceMotion", value: false)
            return "Off"
        case .invertColors:
            writeBool(domain: "com.apple.universalaccess", key: "invertColors", value: false)
            return "Off"
        case .zoom:
            writeBool(domain: "com.apple.universalaccess", key: "closeViewHotkeysEnabled", value: false)
            writeBool(domain: "com.apple.universalaccess", key: "closeViewScrollWheelToggle", value: false)
            return "Off"
        }
    }

    static func openSettings(for fix: Fix) {
        if let url = URL(string: fix.settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }

    static func fixEverythingSafe() -> String {
        ModifierKeySafety.releaseShortcutModifiers()
        for fix in Fix.allCases where fix != .voiceOver && fix != .stuckModifiers {
            _ = Self.fix(fix)
        }
        return "Safe fixes applied"
    }

    private static var voiceOverIsRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.apple.VoiceOver" || app.localizedName == "VoiceOver"
        }
    }

    private static func stopVoiceOver() {
        let starter = "/System/Library/CoreServices/VoiceOver.app/Contents/MacOS/VoiceOverStarter"
        if FileManager.default.fileExists(atPath: starter) {
            _ = run(starter, ["-stop"])
        }

        if voiceOverIsRunning {
            openSettings(for: .voiceOver)
        }
    }

    private static func defaultsBool(domain: String, key: String) -> Bool {
        defaultsRead(domain: domain, key: key)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .matchesTruthyDefaultsValue
    }

    private static func defaultsInt(domain: String, key: String) -> Int {
        Int(defaultsRead(domain: domain, key: key).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func defaultsRead(domain: String, key: String) -> String {
        run("/usr/bin/defaults", ["read", domain, key])
    }

    private static func writeBool(domain: String, key: String, value: Bool) {
        _ = run("/usr/bin/defaults", ["write", domain, key, "-bool", value ? "true" : "false"])
    }

    private static func writeInt(domain: String, key: String, value: Int) {
        _ = run("/usr/bin/defaults", ["write", domain, key, "-int", "\(value)"])
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

private extension String {
    var matchesTruthyDefaultsValue: Bool {
        self == "1" || self == "true" || self == "yes" || self == "on"
    }
}
