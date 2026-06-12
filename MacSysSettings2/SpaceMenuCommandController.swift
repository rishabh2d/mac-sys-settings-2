//
//  SpaceMenuCommandController.swift
//  MacSysSettings2
//
//  Created by Codex on 06/12/26.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class SpaceMenuCommandController {
    static let shared = SpaceMenuCommandController()

    private init() {}

    func showMissionControl() {
        pressControlArrow(keyCode: CGKeyCode(kVK_UpArrow))
    }

    func moveSpaceLeft() {
        pressControlArrow(keyCode: CGKeyCode(kVK_LeftArrow))
    }

    func moveSpaceRight() {
        pressControlArrow(keyCode: CGKeyCode(kVK_RightArrow))
    }

    private func pressControlArrow(keyCode: CGKeyCode) {
        ModifierKeySafety.releaseShortcutModifiers()

        let source = CGEventSource(stateID: .hidSystemState)
        let flags: CGEventFlags = [.maskControl]

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
