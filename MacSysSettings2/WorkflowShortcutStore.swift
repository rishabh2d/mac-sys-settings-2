//
//  WorkflowShortcutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Foundation

enum WorkflowShortcutRecipe: String, CaseIterable, Identifiable {
    case startWork
    case meetingMode
    case deepWork
    case presentationMode
    case saveTonight
    case restoreMorning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startWork: return "Start Work Preset"
        case .meetingMode: return "Meeting Mode"
        case .deepWork: return "Deep Work Mode"
        case .presentationMode: return "Presentation Mode"
        case .saveTonight: return "Save Tonight"
        case .restoreMorning: return "Restore Morning"
        }
    }

    var subtitle: String {
        switch self {
        case .startWork:
            return "Opens Chrome, Cursor, Notes, and Terminal, then applies your Coding layout. Notifications stay on."
        case .meetingMode:
            return "Opens Zoom/Meet and Notes, sets a meeting-friendly volume, and tries your optional Quiet Notifications shortcut."
        case .deepWork:
            return "Opens Cursor, Chrome, Notes, and Terminal, applies your Coding layout, and lowers volume. Notifications stay on."
        case .presentationMode:
            return "Hides desktop icons, opens Keynote, sets volume, and tries your optional Quiet Notifications shortcut."
        case .saveTonight:
            return "Saves the currently running visible apps so you can reopen the same work set tomorrow."
        case .restoreMorning:
            return "Reopens the apps saved by Save Tonight. Window-perfect restore can be layered on later."
        }
    }
}

enum WorkflowShortcutStore {
    static let quietNotificationsShortcutName = "Mac Sys Settings 2 Quiet Notifications"
    private static let snapshotFileName = "save-tonight-apps.json"

    @MainActor
    static func run(_ recipe: WorkflowShortcutRecipe) async -> String {
        switch recipe {
        case .startWork:
            openApps(["Google Chrome", "Cursor", "Notes", "Terminal"])
            let results = await activateMode(.coding)
            return summarize(results, fallback: "Work started")

        case .meetingMode:
            openApps(["zoom.us", "Notes"])
            openURL("https://meet.google.com")
            setSystemVolume(55)
            runQuietNotificationsShortcutIfPresent()
            let results = await activateMode(.meeting)
            return summarize(results, fallback: "Meeting ready")

        case .deepWork:
            openApps(["Cursor", "Google Chrome", "Notes", "Terminal"])
            setSystemVolume(20)
            let results = await activateMode(.coding)
            return summarize(results, fallback: "Deep work ready")

        case .presentationMode:
            setDesktopIconsVisible(false)
            openApps(["Keynote"])
            setSystemVolume(35)
            runQuietNotificationsShortcutIfPresent()
            return "Presentation ready"

        case .saveTonight:
            return saveTonightSnapshot()

        case .restoreMorning:
            return restoreMorningSnapshot()
        }
    }

    static func latestSnapshotSummary() -> String {
        guard let snapshot = loadSnapshot() else {
            return "No saved night yet"
        }

        return "\(snapshot.apps.count) apps saved"
    }

    private static func activateMode(_ name: LayoutPresetName) async -> [String] {
        let modes = WindowLayoutStore.loadModes()
        let mode = modes.first { $0.name == name } ?? WindowMode(name: name, rules: WindowLayoutStore.defaultRules(for: name))
        return await WindowLayoutStore.activate(mode)
    }

    private static func summarize(_ results: [String], fallback: String) -> String {
        let needsAttention = results.contains { result in
            result.contains("required")
                || result.contains("not found")
                || result.contains("not running")
                || result.contains("no window")
        }

        return needsAttention ? "Needs attention" : fallback
    }

    private static func openApps(_ names: [String]) {
        names.forEach(openApp)
    }

    private static func openApp(_ name: String) {
        if let url = appURL(named: name) {
            NSWorkspace.shared.open(url)
        }
    }

    private static func appURL(named name: String) -> URL? {
        let bundleIdentifiers = [
            "Cursor": "com.todesktop.230313mzl4w4u92",
            "Google Chrome": "com.google.Chrome",
            "Notes": "com.apple.Notes",
            "Terminal": "com.apple.Terminal",
            "Keynote": "com.apple.iWork.Keynote",
            "zoom.us": "us.zoom.xos",
            "Zoom": "us.zoom.xos"
        ]

        if let bundleIdentifier = bundleIdentifiers[name],
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }

        for baseURL in [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")] {
            let url = baseURL.appendingPathComponent("\(name).app")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private static func openURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func setSystemVolume(_ volume: Int) {
        runProcess("/usr/bin/osascript", ["-e", "set volume output volume \(max(0, min(100, volume)))"])
    }

    private static func runQuietNotificationsShortcutIfPresent() {
        let listOutput = runProcess("/usr/bin/shortcuts", ["list"])
        guard listOutput
            .components(separatedBy: .newlines)
            .contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == quietNotificationsShortcutName }) else {
            return
        }

        _ = runProcess("/usr/bin/shortcuts", ["run", quietNotificationsShortcutName])
    }

    @discardableResult
    private static func setDesktopIconsVisible(_ visible: Bool) -> Bool {
        _ = runProcess("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", visible ? "true" : "false"])
        _ = runProcess("/usr/bin/killall", ["Finder"])
        return true
    }

    private static func saveTonightSnapshot() -> String {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> WorkflowAppSnapshot? in
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let name = app.localizedName else {
                return nil
            }

            return WorkflowAppSnapshot(
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                bundlePath: app.bundleURL?.path
            )
        }
        .uniqued()
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let snapshot = WorkflowSnapshot(date: Date(), apps: apps)
        do {
            try FileManager.default.createDirectory(at: snapshotsDirectory(), withIntermediateDirectories: true)
            let data = try JSONEncoder.pretty.encode(snapshot)
            try data.write(to: snapshotURL(), options: .atomic)
            return "Saved \(apps.count) apps"
        } catch {
            return "Could not save"
        }
    }

    private static func restoreMorningSnapshot() -> String {
        guard let snapshot = loadSnapshot() else {
            return "No saved night"
        }

        var opened = 0
        for app in snapshot.apps {
            if let bundleIdentifier = app.bundleIdentifier,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                NSWorkspace.shared.open(url)
                opened += 1
            } else if let path = app.bundlePath, FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                opened += 1
            }
        }

        return "Opened \(opened) apps"
    }

    private static func loadSnapshot() -> WorkflowSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL()) else {
            return nil
        }

        return try? JSONDecoder().decode(WorkflowSnapshot.self, from: data)
    }

    private static func snapshotsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Mac Sys Settings 2/WorkflowSnapshots", isDirectory: true)
    }

    private static func snapshotURL() -> URL {
        snapshotsDirectory().appendingPathComponent(snapshotFileName)
    }

    @discardableResult
    private static func runProcess(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
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

private struct WorkflowSnapshot: Codable {
    let date: Date
    let apps: [WorkflowAppSnapshot]
}

private struct WorkflowAppSnapshot: Codable, Hashable {
    let name: String
    let bundleIdentifier: String?
    let bundlePath: String?
}

private extension Array where Element == WorkflowAppSnapshot {
    func uniqued() -> [WorkflowAppSnapshot] {
        var seen = Set<String>()
        return filter { app in
            let key = app.bundleIdentifier ?? app.bundlePath ?? app.name
            return seen.insert(key).inserted
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
