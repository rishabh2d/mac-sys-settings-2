//
//  SystemAudioState.swift
//  MacSysSettings2
//
//  Created by Codex on 07/04/26.
//

import Foundation

enum SystemAudioState {
    static func currentOutputMuted() -> Bool {
        let script = NSAppleScript(source: "output muted of (get volume settings)")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)

        if let error {
            print("MacSysSettings2: failed to read output mute state: \(error)")
            return false
        }

        return result?.booleanValue ?? false
    }
}
