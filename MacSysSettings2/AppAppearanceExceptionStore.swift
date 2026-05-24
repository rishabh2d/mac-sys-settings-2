//
//  AppAppearanceExceptionStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Foundation

struct AppAppearanceException: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let path: String
}

enum AppAppearanceExceptionStore {
    static let didChangeNotification = Notification.Name("AppAppearanceExceptionDidChange")

    private static let exceptionsKey = "appearance.lightExceptions.v1"
    private static let darkModeKey = "appearance.systemDarkMode.enabled"
    private static let notesLightBackgroundKey = "appearance.notesLightBackground.enabled"
    private static let supportedExceptions = [
        AppAppearanceException(
            id: "com.apple.Notes",
            name: "Notes",
            bundleIdentifier: "com.apple.Notes",
            path: "/System/Applications/Notes.app"
        )
    ]

    static var systemDarkModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: darkModeKey)
    }

    static var notesLightBackgroundEnabled: Bool {
        UserDefaults.standard.bool(forKey: notesLightBackgroundKey)
    }

    static func exceptions() -> [AppAppearanceException] {
        guard let data = UserDefaults.standard.data(forKey: exceptionsKey),
              let decoded = try? JSONDecoder().decode([AppAppearanceException].self, from: data) else {
            return []
        }
        let supportedBundleIDs = Set(supportedExceptions.map(\.bundleIdentifier))
        return decoded
            .filter { supportedBundleIDs.contains($0.bundleIdentifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static var notesException: AppAppearanceException {
        supportedExceptions[0]
    }

    static var notesLightExceptionEnabled: Bool {
        exceptions().contains { $0.bundleIdentifier == notesException.bundleIdentifier }
    }

    @discardableResult
    static func setSystemDarkModeEnabled(_ enabled: Bool) -> Bool {
        UserDefaults.standard.set(enabled, forKey: darkModeKey)
        let didApply = setSystemDarkMode(enabled)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return didApply
    }

    @discardableResult
    static func setNotesLightExceptionEnabled(_ enabled: Bool) -> Bool {
        guard enabled else {
            remove(notesException)
            return true
        }

        let exception = notesException
        var current = exceptions().filter { $0.bundleIdentifier != exception.bundleIdentifier }
        current.append(exception)
        save(current)
        let didApply = applyLightException(bundleIdentifier: exception.bundleIdentifier)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return didApply
    }

    static func remove(_ exception: AppAppearanceException) {
        save(exceptions().filter { $0.bundleIdentifier != exception.bundleIdentifier })
        removeLightException(bundleIdentifier: exception.bundleIdentifier)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func applyAllExceptions() {
        for exception in exceptions() {
            applyLightException(bundleIdentifier: exception.bundleIdentifier)
        }
    }

    static func pruneUnsupportedExceptions() {
        guard let data = UserDefaults.standard.data(forKey: exceptionsKey),
              let decoded = try? JSONDecoder().decode([AppAppearanceException].self, from: data) else {
            return
        }

        let supportedBundleIDs = Set(supportedExceptions.map(\.bundleIdentifier))
        let unsupported = decoded.filter { !supportedBundleIDs.contains($0.bundleIdentifier) }
        for exception in unsupported {
            removeLightException(bundleIdentifier: exception.bundleIdentifier)
        }

        let supported = decoded.filter { supportedBundleIDs.contains($0.bundleIdentifier) }
        if supported.count != decoded.count {
            save(supported)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    @discardableResult
    static func setNotesLightBackgroundEnabled(_ enabled: Bool) -> Bool {
        UserDefaults.standard.set(enabled, forKey: notesLightBackgroundKey)
        let didApply = setNotesContentLightBackground(enabled)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return didApply
    }

    @discardableResult
    static func applyNotesLightBackgroundIfEnabled() -> Bool {
        guard notesLightBackgroundEnabled else { return true }
        return true
    }

    static func isLightExceptionApplied(_ exception: AppAppearanceException) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", exception.bundleIdentifier, "NSRequiresAquaSystemAppearance"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return output == "1" || output == "yes" || output == "true"
        } catch {
            return false
        }
    }

    private static func save(_ exceptions: [AppAppearanceException]) {
        if let data = try? JSONEncoder().encode(exceptions) {
            UserDefaults.standard.set(data, forKey: exceptionsKey)
        }
    }

    private static func setSystemDarkMode(_ enabled: Bool) -> Bool {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled ? "true" : "false")
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func setNotesContentLightBackground(_ keepContentLight: Bool) -> Bool {
        let desiredDarkBackgroundValue = keepContentLight ? "0" : "1"
        let script = """
        tell application "Notes" to activate
        delay 0.4
        tell application "System Events"
            tell process "Notes"
                click menu item "Settings…" of menu "Notes" of menu bar item "Notes" of menu bar 1
                delay 0.4
                if exists window "Notes Settings" then
                    tell window "Notes Settings"
                        set targetCheckbox to missing value
                        repeat with groupItem in groups
                            if exists checkbox "Use dark backgrounds for note content" of groupItem then
                                set targetCheckbox to checkbox "Use dark backgrounds for note content" of groupItem
                                exit repeat
                            end if
                        end repeat
                        if targetCheckbox is missing value then
                            return "missing"
                        end if
                        if (value of targetCheckbox as text) is not "\(desiredDarkBackgroundValue)" then
                            click targetCheckbox
                        end if
                        delay 0.1
                        click button 1
                        return "applied"
                    end tell
                else
                    return "missing"
                end if
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @discardableResult
    private static func applyLightException(bundleIdentifier: String) -> Bool {
        runDefaults(arguments: ["write", bundleIdentifier, "NSRequiresAquaSystemAppearance", "-bool", "YES"])
    }

    private static func removeLightException(bundleIdentifier: String) {
        _ = runDefaults(arguments: ["delete", bundleIdentifier, "NSRequiresAquaSystemAppearance"])
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
}
