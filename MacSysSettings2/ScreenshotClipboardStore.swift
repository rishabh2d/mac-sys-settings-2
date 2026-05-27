//
//  ScreenshotClipboardStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import Foundation

enum ScreenshotClipboardStore {
    static let didChangeNotification = Notification.Name("ScreenshotClipboardDidChange")

    private nonisolated static let enabledKey = "screenshots.clipboard.enabled"
    private nonisolated static let dropPickerEnabledKey = "screenshots.dropPicker.enabled"
    private nonisolated static let autoClearEnabledKey = "screenshots.clipboard.autoClear.enabled"
    private nonisolated static let autoClearMinutesKey = "screenshots.clipboard.autoClear.minutes"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    nonisolated static var dropPickerEnabled: Bool {
        UserDefaults.standard.object(forKey: dropPickerEnabledKey) as? Bool ?? true
    }

    nonisolated static var autoClearEnabled: Bool {
        UserDefaults.standard.object(forKey: autoClearEnabledKey) as? Bool ?? true
    }

    nonisolated static var autoClearMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: autoClearMinutesKey)
        return [1, 5, 10, 30, 60].contains(value) ? value : 10
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        postChange()
    }

    static func setDropPickerEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: dropPickerEnabledKey)
        postChange()
    }

    static func setAutoClearEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoClearEnabledKey)
        postChange()
    }

    static func setAutoClearMinutes(_ minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: autoClearMinutesKey)
        postChange()
    }

    private static func postChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
