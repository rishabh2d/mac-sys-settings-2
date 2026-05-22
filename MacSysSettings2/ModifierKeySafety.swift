//
//  ModifierKeySafety.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import Carbon
import CoreGraphics

enum ModifierKeySafety {
    nonisolated static func releaseShortcutModifiers() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodes: [CGKeyCode] = [
            CGKeyCode(kVK_Option),
            CGKeyCode(kVK_RightOption),
            CGKeyCode(kVK_Control),
            CGKeyCode(kVK_RightControl),
            CGKeyCode(kVK_Shift),
            CGKeyCode(kVK_RightShift),
            CGKeyCode(kVK_Command),
            CGKeyCode(kVK_RightCommand),
            CGKeyCode(kVK_Function)
        ]

        for keyCode in keyCodes {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                continue
            }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
    }

    nonisolated static func releaseAfterShortcutEnds() {
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            releaseShortcutModifiers()
        }
    }
}
