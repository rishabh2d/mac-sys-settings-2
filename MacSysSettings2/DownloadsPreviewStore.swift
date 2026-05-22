//
//  DownloadsPreviewStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum DownloadsPreviewStore {
    static let didChangeNotification = Notification.Name("DownloadsPreviewDidChange")
    private nonisolated static let previewDefaultsKey = "downloads.preview.enabled"
    private nonisolated static let finderDefaultsKey = "downloads.finder.open.enabled"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: previewDefaultsKey) as? Bool ?? true
    }

    nonisolated static var opensFinderOnNewDownload: Bool {
        UserDefaults.standard.bool(forKey: finderDefaultsKey)
    }

    nonisolated static var shouldWatchDownloads: Bool {
        isEnabled || opensFinderOnNewDownload
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: previewDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func setOpensFinderOnNewDownload(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: finderDefaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
