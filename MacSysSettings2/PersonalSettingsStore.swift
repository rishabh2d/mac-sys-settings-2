//
//  PersonalSettingsStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import Foundation

enum PersonalSettingCategory: String, CaseIterable, Identifiable, Codable {
    case shortcut = "Shortcut"
    case screen = "Screen"
    case files = "Files"
    case privacy = "Privacy"
    case workflow = "Workflow"

    var id: String { rawValue }
}

enum PersonalSettingReviewState: String, CaseIterable, Identifiable, Codable {
    case idea = "Idea"
    case needsDetail = "Needs Detail"
    case ready = "Ready"
    case shipped = "Shipped"

    var id: String { rawValue }
}

struct PersonalSettingRequest: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var note: String
    var category: PersonalSettingCategory
    var reviewState: PersonalSettingReviewState
}

enum PersonalSettingsStore {
    static let didChangeNotification = Notification.Name("PersonalSettingsDidChange")
    private static let defaultsKey = "personal.settings.requests.v1"

    static func load() -> [PersonalSettingRequest] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let requests = try? JSONDecoder().decode([PersonalSettingRequest].self, from: data),
              !requests.isEmpty else {
            return defaultRequests()
        }

        return requests
    }

    static func save(_ requests: [PersonalSettingRequest]) {
        if let data = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func defaultRequests() -> [PersonalSettingRequest] {
        [
            PersonalSettingRequest(
                title: "My own shortcut idea",
                note: "Describe the behavior, shortcut, and what should happen before asking to push it.",
                category: .shortcut,
                reviewState: .idea
            ),
            PersonalSettingRequest(
                title: "Personal workflow setting",
                note: "Keep the exact request here until it is clear enough to build.",
                category: .workflow,
                reviewState: .needsDetail
            )
        ]
    }
}
