//
//  FileShelfStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum FileShelfStore {
    static let didChangeNotification = Notification.Name("FileShelfDidChange")
    static let didItemsChangeNotification = Notification.Name("FileShelfItemsDidChange")

    private nonisolated static let enabledKey = "fileShelf.enabled"
    private nonisolated static let urlsKey = "fileShelf.urls.v1"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    nonisolated static func currentURLs() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: urlsKey) ?? []
        return paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func addURLs(_ urls: [URL]) {
        let existing = currentURLs()
        var next = existing
        for url in urls {
            let standardized = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: standardized.path) else { continue }
            guard !next.contains(where: { $0.path == standardized.path }) else { continue }
            next.append(standardized)
        }
        saveURLs(next)
    }

    static func removeURL(_ url: URL) {
        saveURLs(currentURLs().filter { $0.path != url.path })
    }

    static func clear() {
        saveURLs([])
    }

    private static func saveURLs(_ urls: [URL]) {
        UserDefaults.standard.set(urls.map(\.path), forKey: urlsKey)
        NotificationCenter.default.post(name: didItemsChangeNotification, object: nil)
    }
}
