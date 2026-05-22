//
//  AppAppearanceStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppAppearanceStore {
    static let didChangeNotification = Notification.Name("AppAppearanceDidChange")
    private static let modeKey = "app.appearance.mode.v1"

    static var current: AppAppearanceMode {
        guard let rawValue = UserDefaults.standard.string(forKey: modeKey),
              let mode = AppAppearanceMode(rawValue: rawValue) else {
            return .system
        }
        return mode
    }

    static func setMode(_ mode: AppAppearanceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
