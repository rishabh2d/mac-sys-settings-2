//
//  LoginItemStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import Foundation

enum LoginItemStore {
    static let didChangeNotification = Notification.Name("LoginItemStoreDidChange")
    private static let userChoiceKey = "app.launchAtLogin.userChoice.v1"

    static var hasUserChoice: Bool {
        UserDefaults.standard.object(forKey: userChoiceKey) != nil
    }

    static var isEnabled: Bool {
        runAppleScript("""
        tell application "System Events"
          return exists login item "Mac Sys Settings 2"
        end tell
        """) == "true"
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool, rememberChoice: Bool = true) -> Bool {
        let appPath = Bundle.main.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
        let script: String

        if enabled {
            script = """
            tell application "System Events"
              if exists login item "Mac Sys Settings 2" then delete login item "Mac Sys Settings 2"
              make login item at end with properties {path:"\(appPath)", hidden:false, name:"Mac Sys Settings 2"}
            end tell
            """
        } else {
            script = """
            tell application "System Events"
              if exists login item "Mac Sys Settings 2" then delete login item "Mac Sys Settings 2"
            end tell
            """
        }

        _ = runAppleScript(script)
        if rememberChoice {
            UserDefaults.standard.set(enabled, forKey: userChoiceKey)
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        return isEnabled
    }

    static func enableByDefaultIfNeeded() {
        guard !hasUserChoice else { return }
        setEnabled(true, rememberChoice: false)
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return result?.stringValue
    }
}
