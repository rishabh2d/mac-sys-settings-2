//
//  SettingsBackupStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import ApplicationServices
import Foundation

struct SettingsBackupGroup: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let domains: [String]
    let isExportable: Bool
}

struct SettingsBackupSummary {
    let folderURL: URL
    let exportedCount: Int
    let skippedCount: Int
}

enum SettingsBackupStore {
    static let didChangeNotification = Notification.Name("SettingsBackupDidChange")

    private nonisolated static let lastBackupPathKey = "settingsBackup.lastPath"
    private nonisolated static let lastStatusKey = "settingsBackup.lastStatus"

    static let groups: [SettingsBackupGroup] = [
        SettingsBackupGroup(
            id: "macsys",
            title: "Mac Sys Settings 2 preferences",
            subtitle: "All toggles, shortcuts, layout presets, personal settings, and app-owned configuration.",
            domains: ["com.rishabh.MacSysSettings2"],
            isExportable: true
        ),
        SettingsBackupGroup(
            id: "finder",
            title: "Finder preferences",
            subtitle: "Finder view defaults, desktop behavior, sidebar-ish preferences where macOS stores them in normal defaults.",
            domains: ["com.apple.finder", "com.apple.sidebarlists"],
            isExportable: true
        ),
        SettingsBackupGroup(
            id: "dock",
            title: "Dock preferences",
            subtitle: "Dock animation, hiding, hidden-app indicator, and other Dock defaults.",
            domains: ["com.apple.dock"],
            isExportable: true
        ),
        SettingsBackupGroup(
            id: "keyboard",
            title: "Keyboard shortcuts/preferences",
            subtitle: "Global keyboard defaults, symbolic hotkeys, and input source preferences.",
            domains: ["NSGlobalDomain", "com.apple.symbolichotkeys", "com.apple.HIToolbox"],
            isExportable: true
        ),
        SettingsBackupGroup(
            id: "privacy",
            title: "Privacy status checklist",
            subtitle: "Accessibility, Screen Recording, Bluetooth, Microphone, Input Monitoring status notes only. macOS does not allow exporting passwords or permission grants.",
            domains: [],
            isExportable: false
        ),
        SettingsBackupGroup(
            id: "apps",
            title: "Selected app preferences",
            subtitle: "Safe defaults for common apps like Chrome, Safari, Raycast, Telegram, WhatsApp, and Edge when those domains are readable.",
            domains: [
                "com.google.Chrome",
                "com.apple.Safari",
                "com.raycast.macos",
                "ru.keepcoder.Telegram",
                "net.whatsapp.WhatsApp",
                "com.microsoft.edgemac"
            ],
            isExportable: true
        )
    ]

    static var lastStatus: String {
        UserDefaults.standard.string(forKey: lastStatusKey) ?? "Ready"
    }

    static var lastBackupPath: String {
        UserDefaults.standard.string(forKey: lastBackupPathKey) ?? ""
    }

    @discardableResult
    static func exportBackup() -> SettingsBackupSummary? {
        let folder = defaultBackupFolder()
        let plistFolder = folder.appendingPathComponent("Preference Plists", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: plistFolder, withIntermediateDirectories: true)
        } catch {
            setStatus("Could not create folder")
            return nil
        }

        var exported = 0
        var skipped = 0
        var manifest: [String] = [
            "Mac Sys Settings 2 Backup",
            "Created: \(Self.dateFormatter.string(from: Date()))",
            "",
            "This backup stores normal local preference domains only.",
            "It does not export passwords, keychain items, files, or macOS privacy permission grants.",
            ""
        ]

        for group in groups {
            manifest.append("## \(group.title)")
            manifest.append(group.subtitle)

            guard group.isExportable else {
                manifest.append("Status: checklist only")
                manifest.append(contentsOf: privacyChecklistLines())
                manifest.append("")
                continue
            }

            for domain in group.domains {
                let target = plistFolder.appendingPathComponent(safeFilename(for: domain)).appendingPathExtension("plist")
                if exportDomain(domain, to: target) {
                    exported += 1
                    manifest.append("- Exported \(domain)")
                } else {
                    skipped += 1
                    manifest.append("- Skipped \(domain)")
                }
            }
            manifest.append("")
        }

        let manifestURL = folder.appendingPathComponent("README.txt")
        do {
            try manifest.joined(separator: "\n").write(to: manifestURL, atomically: true, encoding: .utf8)
        } catch {
            setStatus("Exported, readme failed")
        }

        UserDefaults.standard.set(folder.path, forKey: lastBackupPathKey)
        setStatus("Exported \(exported)")
        NSWorkspace.shared.activateFileViewerSelecting([folder])
        return SettingsBackupSummary(folderURL: folder, exportedCount: exported, skippedCount: skipped)
    }

    static func chooseBackupToImport(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Choose a Mac Sys Settings 2 backup folder"
        panel.prompt = "Import"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        panel.begin { response in
            guard response == .OK, let folder = panel.url else {
                completion("Cancelled")
                return
            }
            completion(importBackup(from: folder))
        }
    }

    @discardableResult
    static func importBackup(from folder: URL) -> String {
        let plistFolder = folder.appendingPathComponent("Preference Plists", isDirectory: true)
        var imported = 0

        for group in groups where group.isExportable {
            for domain in group.domains {
                let source = plistFolder.appendingPathComponent(safeFilename(for: domain)).appendingPathExtension("plist")
                guard FileManager.default.fileExists(atPath: source.path) else { continue }
                if importDomain(domain, from: source) {
                    imported += 1
                }
            }
        }

        let status = imported > 0 ? "Imported \(imported)" : "Nothing imported"
        setStatus(status)
        return status
    }

    static func revealLastBackup() {
        guard !lastBackupPath.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: lastBackupPath)])
    }

    private static func defaultBackupFolder() -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop", isDirectory: true)
        let name = "Mac Sys Settings 2 Backup \(Self.filenameDateFormatter.string(from: Date()))"
        return desktop.appendingPathComponent(name, isDirectory: true)
    }

    private static func exportDomain(_ domain: String, to url: URL) -> Bool {
        runDefaults(arguments: ["export", domain, url.path])
    }

    private static func importDomain(_ domain: String, from url: URL) -> Bool {
        runDefaults(arguments: ["import", domain, url.path])
    }

    private static func runDefaults(arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
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

    private static func privacyChecklistLines() -> [String] {
        [
            "- Accessibility: \(AXIsProcessTrusted() ? "Allowed" : "Needs setup")",
            "- Screen Recording: \(CGPreflightScreenCaptureAccess() ? "Allowed" : "Needs setup")",
            "- Bluetooth: check Setup Cost after import",
            "- Microphone: check Setup Cost after import",
            "- Input Monitoring: check Setup Cost after import",
            "- Files and Folders: check Setup Cost after import"
        ]
    }

    private static func safeFilename(for domain: String) -> String {
        domain.replacingOccurrences(of: "/", with: "_")
    }

    private static func setStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: lastStatusKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()
}
