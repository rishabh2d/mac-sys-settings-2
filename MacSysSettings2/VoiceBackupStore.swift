//
//  VoiceBackupStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/28/26.
//

import Foundation
import Security

enum VoiceBackupStore {
    static let didChangeNotification = Notification.Name("VoiceBackupDidChange")

    private nonisolated static let enabledKey = "mic.voiceBackup.enabled"
    private nonisolated static let keychainService = "com.rishabh.MacSysSettings2.voiceBackup"
    private nonisolated static let openAIAccount = "openai-api-key"

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func openAIKey() -> String? {
        var query = baseKeychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return key
    }

    static func saveOpenAIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }

        SecItemDelete(baseKeychainQuery() as CFDictionary)

        var query = baseKeychainQuery()
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func deleteOpenAIKey() {
        SecItemDelete(baseKeychainQuery() as CFDictionary)
    }

    private static func baseKeychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: openAIAccount
        ]
    }
}
