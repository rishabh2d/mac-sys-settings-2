//
//  FilePickerDefaultFolderStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

struct FilePickerDefaultFolderRule: Codable, Identifiable, Equatable {
    var id: UUID
    var appName: String
    var bundleIdentifier: String
    var folderPath: String
    var isEnabled: Bool

    var folderName: String {
        URL(fileURLWithPath: folderPath).lastPathComponent
    }
}

enum FilePickerDefaultFolderStore {
    static let didChangeNotification = Notification.Name("FilePickerDefaultFolderDidChange")

    private static let enabledKey = "finder.filePickerDefaults.enabled"
    private static let rulesKey = "finder.filePickerDefaults.rules.v1"
    private static let statusKey = "finder.filePickerDefaults.status"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static var lastStatus: String {
        UserDefaults.standard.string(forKey: statusKey) ?? "Ready"
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        setLastStatus(enabled ? "Watching" : "Off", notify: false)
        notify()
    }

    static func rules() -> [FilePickerDefaultFolderRule] {
        guard let data = UserDefaults.standard.data(forKey: rulesKey),
              let decoded = try? JSONDecoder().decode([FilePickerDefaultFolderRule].self, from: data) else {
            return []
        }
        return decoded
    }

    static func addRule(appURL: URL, folderURL: URL) {
        guard let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            setLastStatus("Could not read app")
            return
        }

        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        var current = rules().filter { $0.bundleIdentifier != bundleIdentifier }
        current.append(
            FilePickerDefaultFolderRule(
                id: UUID(),
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                folderPath: folderURL.path,
                isEnabled: true
            )
        )
        save(current.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending })
        setLastStatus("Saved \(appName)")
    }

    static func setRuleEnabled(_ rule: FilePickerDefaultFolderRule, enabled: Bool) {
        var current = rules()
        guard let index = current.firstIndex(where: { $0.id == rule.id }) else { return }
        current[index].isEnabled = enabled
        save(current)
        setLastStatus(enabled ? "Rule on" : "Rule off")
    }

    static func remove(_ rule: FilePickerDefaultFolderRule) {
        save(rules().filter { $0.id != rule.id })
        setLastStatus("Removed")
    }

    static func enabledRule(for bundleIdentifier: String) -> FilePickerDefaultFolderRule? {
        guard isEnabled else { return nil }
        return rules().first { $0.isEnabled && $0.bundleIdentifier == bundleIdentifier }
    }

    static func setLastStatus(_ status: String, notify shouldNotify: Bool = true) {
        UserDefaults.standard.set(status, forKey: statusKey)
        if shouldNotify {
            notify()
        }
    }

    static func chooseRuleSource(completion: @escaping (Bool) -> Void) {
        let appPanel = NSOpenPanel()
        appPanel.title = "Choose an app"
        appPanel.prompt = "Choose"
        appPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        appPanel.allowedContentTypes = [.applicationBundle]
        appPanel.allowsMultipleSelection = false
        appPanel.canChooseDirectories = false
        appPanel.canChooseFiles = true

        appPanel.begin { response in
            guard response == .OK, let appURL = appPanel.url else {
                completion(false)
                return
            }

            let folderPanel = NSOpenPanel()
            folderPanel.title = "Choose default folder"
            folderPanel.prompt = "Use Folder"
            folderPanel.allowsMultipleSelection = false
            folderPanel.canChooseDirectories = true
            folderPanel.canChooseFiles = false
            folderPanel.begin { folderResponse in
                guard folderResponse == .OK, let folderURL = folderPanel.url else {
                    completion(false)
                    return
                }
                addRule(appURL: appURL, folderURL: folderURL)
                completion(true)
            }
        }
    }

    private static func save(_ rules: [FilePickerDefaultFolderRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
        notify()
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
