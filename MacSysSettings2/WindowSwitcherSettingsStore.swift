//
//  WindowSwitcherSettingsStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import Foundation

enum WindowSwitcherSettingsStore {
    static let didChangeNotification = Notification.Name("WindowSwitcherSettingsDidChange")

    private enum Key {
        nonisolated static let enabled = "windowSwitcher.enabled"
        nonisolated static let showThumbnails = "windowSwitcher.showThumbnails"
        nonisolated static let includeMinimized = "windowSwitcher.includeMinimized"
        nonisolated static let currentMonitorFirst = "windowSwitcher.currentMonitorFirst"
        nonisolated static let moveCursorToSelectedMonitor = "windowSwitcher.moveCursorToSelectedMonitor"
        nonisolated static let bottomRightHotCorner = "windowSwitcher.bottomRightHotCorner"
        nonisolated static let excludeFinder = "windowSwitcher.excludeFinder"
        nonisolated static let excludeHiddenApps = "windowSwitcher.excludeHiddenApps"
        nonisolated static let defaultsSeeded = "windowSwitcher.defaultsSeeded"
    }

    nonisolated static var enabled: Bool {
        UserDefaults.standard.bool(forKey: Key.enabled)
    }

    nonisolated static var showThumbnails: Bool {
        bool(for: Key.showThumbnails, defaultValue: false)
    }

    nonisolated static var includeMinimized: Bool {
        bool(for: Key.includeMinimized, defaultValue: false)
    }

    nonisolated static var currentMonitorFirst: Bool {
        bool(for: Key.currentMonitorFirst, defaultValue: true)
    }

    nonisolated static var moveCursorToSelectedMonitor: Bool {
        bool(for: Key.moveCursorToSelectedMonitor, defaultValue: false)
    }

    nonisolated static var bottomRightHotCorner: Bool {
        bool(for: Key.bottomRightHotCorner, defaultValue: false)
    }

    nonisolated static var excludeFinder: Bool {
        bool(for: Key.excludeFinder, defaultValue: false)
    }

    nonisolated static var excludeHiddenApps: Bool {
        bool(for: Key.excludeHiddenApps, defaultValue: true)
    }

    static func seedDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Key.defaultsSeeded) else { return }

        UserDefaults.standard.set(false, forKey: Key.enabled)
        UserDefaults.standard.set(false, forKey: Key.showThumbnails)
        UserDefaults.standard.set(false, forKey: Key.includeMinimized)
        UserDefaults.standard.set(true, forKey: Key.currentMonitorFirst)
        UserDefaults.standard.set(false, forKey: Key.moveCursorToSelectedMonitor)
        UserDefaults.standard.set(false, forKey: Key.bottomRightHotCorner)
        UserDefaults.standard.set(false, forKey: Key.excludeFinder)
        UserDefaults.standard.set(true, forKey: Key.excludeHiddenApps)
        UserDefaults.standard.set(true, forKey: Key.defaultsSeeded)
    }

    static func setEnabled(_ enabled: Bool) {
        set(enabled, for: Key.enabled)
    }

    static func setShowThumbnails(_ enabled: Bool) {
        set(enabled, for: Key.showThumbnails)
    }

    static func setIncludeMinimized(_ enabled: Bool) {
        set(enabled, for: Key.includeMinimized)
    }

    static func setCurrentMonitorFirst(_ enabled: Bool) {
        set(enabled, for: Key.currentMonitorFirst)
    }

    static func setMoveCursorToSelectedMonitor(_ enabled: Bool) {
        set(enabled, for: Key.moveCursorToSelectedMonitor)
    }

    static func setBottomRightHotCorner(_ enabled: Bool) {
        set(enabled, for: Key.bottomRightHotCorner)
    }

    static func setExcludeFinder(_ enabled: Bool) {
        set(enabled, for: Key.excludeFinder)
    }

    static func setExcludeHiddenApps(_ enabled: Bool) {
        set(enabled, for: Key.excludeHiddenApps)
    }

    private nonisolated static func bool(for key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private static func set(_ enabled: Bool, for key: String) {
        UserDefaults.standard.set(enabled, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
