//
//  SettingsChangeHistoryStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Combine
import Foundation

struct SettingsChangeEntry: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case app = "App"
        case macOS = "macOS"
    }

    let id: UUID
    let date: Date
    let source: Source
    let name: String
    let oldValue: String
    let newValue: String
}

enum SettingsChangeHistoryStore {
    static let didChangeNotification = Notification.Name("SettingsChangeHistoryDidChange")

    private static let entriesKey = "settings.changeHistory.entries.v1"
    private static let snapshotKey = "settings.changeHistory.snapshot.v1"
    private static let maxEntries = 80

    static func entries() -> [SettingsChangeEntry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([SettingsChangeEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }

    static func currentSnapshot() -> [String: String] {
        trackedSettings().reduce(into: [:]) { result, setting in
            result[setting.key] = setting.value()
        }
    }

    @discardableResult
    static func checkNow() -> [SettingsChangeEntry] {
        let previous = loadSnapshot()
        let current = currentSnapshot()
        saveSnapshot(current)

        guard !previous.isEmpty else {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
            return []
        }

        let labels = Dictionary(uniqueKeysWithValues: trackedSettings().map { ($0.key, $0) })
        let changed = current.compactMap { key, newValue -> SettingsChangeEntry? in
            guard let oldValue = previous[key], oldValue != newValue else { return nil }
            let label = labels[key]
            return SettingsChangeEntry(
                id: UUID(),
                date: Date(),
                source: label?.source ?? .app,
                name: label?.name ?? key,
                oldValue: oldValue,
                newValue: newValue
            )
        }

        guard !changed.isEmpty else {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
            return []
        }

        saveEntries(Array((changed + entries()).prefix(maxEntries)))
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return changed
    }

    static func resetBaseline() {
        saveSnapshot(currentSnapshot())
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func clearEntries() {
        UserDefaults.standard.removeObject(forKey: entriesKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func loadSnapshot() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: snapshotKey) as? [String: String] ?? [:]
    }

    private static func saveSnapshot(_ snapshot: [String: String]) {
        UserDefaults.standard.set(snapshot, forKey: snapshotKey)
    }

    private static func saveEntries(_ entries: [SettingsChangeEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private struct TrackedSetting {
        let key: String
        let name: String
        let source: SettingsChangeEntry.Source
        let value: () -> String
    }

    private static func trackedSettings() -> [TrackedSetting] {
        [
            app("general.loginItem", "Open at login") { LoginItemStore.isEnabled.onOff },
            app("general.appearance", "Appearance") { AppAppearanceStore.current.rawValue },
            app("general.systemDarkMode", "Mac dark mode") { AppAppearanceExceptionStore.systemDarkModeEnabled.onOff },
            app("general.lightExceptions", "Per-app light exceptions") { "\(AppAppearanceExceptionStore.exceptions().count)" },
            app("general.notesLightBackground", "Notes light note content") { AppAppearanceExceptionStore.notesLightBackgroundEnabled.onOff },
            app("general.hideNativeBattery", "Hide Apple battery icon") { BatteryMenuStore.hidesNativeBatteryIcon.onOff },
            app("general.fastMinimize", "Fast minimize animation") { DockMinimizeAnimationStore.isEnabled.onOff },
            app("general.instantCommandM", "Command-M instant minimize") { InstantMinimizeStore.isEnabled.onOff },
            app("general.instantDockReveal", "Instant Dock reveal") { DockRevealStore.isEnabled.onOff },
            app("general.dimHiddenDockApps", "Dim hidden Dock apps") { DockHiddenAppsStore.isEnabled.onOff },
            app("downloads.preview", "Download preview") { DownloadsPreviewStore.isEnabled.onOff },
            app("downloads.openFinder", "Open Downloads newest first") { DownloadsPreviewStore.opensFinderOnNewDownload.onOff },
            app("clipboard.copyScreenshots", "Copy screenshots to clipboard") { ScreenshotClipboardStore.isEnabled.onOff },
            app("clipboard.autoClear", "Screenshot clipboard auto-clear") { ScreenshotClipboardStore.autoClearEnabled.onOff },
            mac("mac.dock.slowMotionAllowed", "Dock slow-motion Shift animations") { defaultsRead("com.apple.dock", "slow-motion-allowed") },
            app("finder.sortShortcut", "Finder sort chooser") { FinderSortShortcutStore.isEnabled.onOff },
            app("finder.filePickerDefaults", "Open/Save folder defaults") { FilePickerDefaultFolderStore.isEnabled.onOff },
            app("finder.filePickerRules", "Open/Save app-folder rules") { "\(FilePickerDefaultFolderStore.rules().count)" },
            app("shelf.enabled", "File shelf") { FileShelfStore.isEnabled.onOff },
            app("screen.moveShortcut", "Move monitor shortcut") { ScreenShortcut.current().displayText },
            app("screen.controlArrow", "Control-Arrow sizing") { ControlArrowSnapStore.isEnabled.onOff },
            app("screen.snapAfterMonitorDrag", "Fill after monitor drag") { ControlArrowSnapStore.snapAfterMonitorDragEnabled.onOff },
            app("screen.optionUp", "Option-Up full snap") { UpSnapAliasStore.optionUpEnabled.onOff },
            app("screen.commandUp", "Command-Up full snap") { UpSnapAliasStore.commandUpEnabled.onOff },
            app("screen.browserTabSnap", "Command-Option browser tab snap") { BrowserTabSnapStore.isEnabled.onOff },
            app("screen.quickOppositeArrow", "Quick opposite arrow tab snap") { BrowserTabSnapStore.quickOppositeArrowEnabled.onOff },
            app("screen.browserMonitorChoice", "Browser tab/window monitor choice") { BrowserMonitorMoveStore.isEnabled.onOff },
            app("screen.monitorMove", "Move all windows on monitor") { MonitorMoveShortcutStore.isEnabled.onOff },
            app("screen.monitorMoveOthers", "Move other windows on monitor") { MonitorMoveOthersShortcutStore.isEnabled.onOff },
            app("screen.spaceSwitching", "Control-Arrow Spaces switching") { SpaceSwitchShortcutStore.isEnabled.onOff },
            app("screen.hoverFocus", "Hover focus") { HoverFocusStore.isEnabled.onOff },
            app("screen.cursorJump", "Cursor Jump") { CursorJumpStore.isEnabled.onOff },
            app("screen.cursorLocator", "Cursor locator ring") { CursorJumpStore.locatorEnabled.onOff },
            app("screen.cursorLocatorAfterJump", "Cursor locator after jump") { CursorJumpStore.locatorAfterJumpEnabled.onOff },
            app("screen.autoKeyPress", "Auto key press") { AutoKeyPressStore.isEnabled.onOff },
            app("screen.autoKeyPressShortcut", "Auto key press shortcut") { AutoKeyPressStore.shortcut.displayText },
            app("screen.autoKeyPressKey", "Auto key press key") { AutoKeyPressStore.targetKeyName },
            app("screen.autoKeyPressInterval", "Auto key press interval") { "\(AutoKeyPressStore.interval)s" },
            app("screen.audioTabJump", "Audio tab jump") { AudioTabJumpStore.isEnabled.onOff },
            app("screen.audioTabJumpShortcut", "Audio tab jump shortcut") { AudioTabJumpStore.shortcut.displayText },
            app("screen.pinWindow", "Pin FaceTime") { PinWindowStore.isEnabled.onOff },
            app("screen.desktopIcons", "Desktop icons shortcut") { DesktopIconsShortcutStore.isEnabled.onOff },
            app("screen.commandH", "Command-H hide toggle") { CommandHideToggleStore.isEnabled.onOff },
            app("screen.commandShiftH", "Command-Shift-H monitor hide") { CommandShiftHideMonitorStore.isEnabled.onOff },
            app("screen.focusedDisplayMissionControl", "Mission Control per display") { DisplaySpacesStore.missionControlFocusedDisplayOnly.onOff },
            app("screen.autoscroll", "Autoscroll") { AutoScrollStore.isEnabled.onOff },
            app("screen.fullscreenEscape", "Fullscreen Escape") { FullscreenEscapeStore.isEnabled.onOff },
            app("windowSwitcher.enabled", "Option-Tab window switcher") { WindowSwitcherSettingsStore.enabled.onOff },
            app("windowSwitcher.hotCorner", "Window switcher hot corner") { WindowSwitcherSettingsStore.bottomRightHotCorner.onOff },
            app("mic.bluetoothPrompt", "Bluetooth mic prompt") { BluetoothAudioInputPromptStore.isEnabled.onOff },
            app("mic.bluetoothSleep", "Bluetooth off during sleep") { BluetoothSleepStore.isEnabled.onOff },
            app("mic.bluetoothSleepBatteryOnly", "Bluetooth sleep only on battery") { BluetoothSleepStore.onlyOnBattery.onOff },
            app("mic.networkWarning", "Mic Wi-Fi warning") { MicNetworkWarningStore.isEnabled.onOff },
            app("mic.voiceBackup", "Voice Backup") { VoiceBackupStore.isEnabled.onOff },
            app("layouts.count", "Saved modes") { "\(WindowLayoutStore.loadModes().count)" },
            app("personal.count", "Personal settings") { "\(PersonalSettingsStore.load().count)" },
            mac("mac.dock.mineffect", "Dock minimize effect") { defaultsRead("com.apple.dock", "mineffect") },
            mac("mac.dock.autohideDelay", "Dock reveal delay") { defaultsRead("com.apple.dock", "autohide-delay") },
            mac("mac.dock.autohideTime", "Dock reveal animation time") { defaultsRead("com.apple.dock", "autohide-time-modifier") },
            mac("mac.dock.showHidden", "Dock hidden-app dimming") { defaultsRead("com.apple.dock", "showhidden") },
            mac("mac.finder.desktopIcons", "Finder desktop icons") { defaultsRead("com.apple.finder", "CreateDesktop") },
            mac("mac.spaces.spansDisplays", "Displays have separate Spaces") { defaultsRead("com.apple.spaces", "spans-displays") },
            mac("mac.controlCenter.batteryVisible", "Apple battery menu icon") { defaultsRead("com.apple.controlcenter", "NSStatusItem Visible Battery") },
            mac("mac.controlCenter.ccBatteryVisible", "Control Center battery icon") { defaultsRead("com.apple.controlcenter", "NSStatusItem VisibleCC Battery") }
        ]
    }

    private static func app(_ key: String, _ name: String, value: @escaping () -> String) -> TrackedSetting {
        TrackedSetting(key: key, name: name, source: .app, value: value)
    }

    private static func mac(_ key: String, _ name: String, value: @escaping () -> String) -> TrackedSetting {
        TrackedSetting(key: key, name: name, source: .macOS, value: value)
    }

    private static func defaultsRead(_ domain: String, _ key: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", domain, key]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "Not set" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output.isEmpty ? "Empty" : output
        } catch {
            return "Unavailable"
        }
    }
}

@MainActor
final class SettingsChangeHistoryController: ObservableObject {
    static let shared = SettingsChangeHistoryController()

    @Published private(set) var lastStatus = "Ready"
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        _ = SettingsChangeHistoryStore.checkNow()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkNow()
            }
        }
        timer?.tolerance = 1
    }

    func checkNow() {
        let changes = SettingsChangeHistoryStore.checkNow()
        if changes.isEmpty {
            lastStatus = "No changes"
        } else {
            lastStatus = "\(changes.count) change\(changes.count == 1 ? "" : "s")"
        }
    }
}

private extension Bool {
    var onOff: String {
        self ? "On" : "Off"
    }
}
