//
//  SpaceMenuCommandController.swift
//  MacSysSettings2
//
//  Created by Codex on 06/12/26.
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Darwin

@MainActor
final class SpaceMenuCommandController {
    static let shared = SpaceMenuCommandController()

    private typealias CGSConnectionID = UInt32
    private typealias CGSSpaceID = UInt64
    private typealias CGSMainConnectionIDProc = @convention(c) () -> CGSConnectionID
    private typealias CGSCopyManagedDisplaySpacesProc = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>?
    private typealias CGSManagedDisplaySetCurrentSpaceProc = @convention(c) (CGSConnectionID, CFString, CGSSpaceID) -> Int32

    private init() {}

    func showMissionControl() {
        runOpenBundle("com.apple.exposelauncher")
    }

    func moveSpaceLeft(on screen: NSScreen? = nil) {
        if !switchSpace(direction: -1, screen: screen) {
            pressControlArrow(keyCode: CGKeyCode(kVK_LeftArrow))
        }
    }

    func moveSpaceRight(on screen: NSScreen? = nil) {
        if !switchSpace(direction: 1, screen: screen) {
            pressControlArrow(keyCode: CGKeyCode(kVK_RightArrow))
        }
    }

    private func runOpenBundle(_ bundleIdentifier: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleIdentifier]
        try? process.run()
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

    private func switchSpace(direction: Int, screen: NSScreen?) -> Bool {
        guard direction == -1 || direction == 1,
              let functions = loadSpacesFunctions(),
              let targetDisplay = displayIdentifier(for: screen) ?? displayIdentifierUnderMouse() else {
            return false
        }

        let connection = functions.mainConnection()
        guard let displays = functions.copyManagedDisplaySpaces(connection)?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }

        guard let target = spaceTarget(in: displays, preferredDisplay: targetDisplay) else {
            return false
        }

        let targetIndex: Int
        if direction < 0 {
            targetIndex = target.currentIndex == 0 ? target.spaceIDs.count - 1 : target.currentIndex - 1
        } else {
            targetIndex = target.currentIndex == target.spaceIDs.count - 1 ? 0 : target.currentIndex + 1
        }

        let result = functions.setCurrentSpace(connection, target.displayIdentifier as CFString, target.spaceIDs[targetIndex])
        return result == 0
    }

    private struct SpaceTarget {
        let displayIdentifier: String
        let currentID: CGSSpaceID
        let currentIndex: Int
        let spaceIDs: [CGSSpaceID]
    }

    private struct SpacesFunctions {
        let mainConnection: CGSMainConnectionIDProc
        let copyManagedDisplaySpaces: CGSCopyManagedDisplaySpacesProc
        let setCurrentSpace: CGSManagedDisplaySetCurrentSpaceProc
    }

    private func loadSpacesFunctions() -> SpacesFunctions? {
        guard let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW),
              let mainSymbol = dlsym(handle, "CGSMainConnectionID"),
              let copySymbol = dlsym(handle, "CGSCopyManagedDisplaySpaces"),
              let setSymbol = dlsym(handle, "CGSManagedDisplaySetCurrentSpace") else {
            return nil
        }

        return SpacesFunctions(
            mainConnection: unsafeBitCast(mainSymbol, to: CGSMainConnectionIDProc.self),
            copyManagedDisplaySpaces: unsafeBitCast(copySymbol, to: CGSCopyManagedDisplaySpacesProc.self),
            setCurrentSpace: unsafeBitCast(setSymbol, to: CGSManagedDisplaySetCurrentSpaceProc.self)
        )
    }

    private func displayIdentifierUnderMouse() -> String? {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
        return displayIdentifier(for: screen)
    }

    private func displayIdentifier(for screen: NSScreen?) -> String? {
        guard let screen,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let identifier = CFUUIDCreateString(nil, uuid) as String? else {
            return nil
        }

        return identifier
    }

    private func spaceID(from dictionary: [String: Any]) -> CGSSpaceID? {
        if let id = dictionary["id64"] as? CGSSpaceID {
            return id
        }
        if let id = dictionary["ManagedSpaceID"] as? CGSSpaceID {
            return id
        }
        if let id = dictionary["id64"] as? NSNumber {
            return id.uint64Value
        }
        if let id = dictionary["ManagedSpaceID"] as? NSNumber {
            return id.uint64Value
        }
        return nil
    }

    private func spaceTarget(in displays: [[String: Any]], preferredDisplay: String) -> SpaceTarget? {
        let candidates = displays.compactMap(spaceTarget(from:))

        if let preferred = candidates.first(where: { $0.displayIdentifier == preferredDisplay }),
           preferred.spaceIDs.count > 1 {
            return preferred
        }

        return candidates.first { $0.spaceIDs.count > 1 }
    }

    private func spaceTarget(from display: [String: Any]) -> SpaceTarget? {
        guard let displayIdentifier = display["Display Identifier"] as? String,
              let current = display["Current Space"] as? [String: Any],
              let currentID = spaceID(from: current),
              let spaces = display["Spaces"] as? [[String: Any]] else {
            return nil
        }

        let spaceIDs = spaces.compactMap(spaceID(from:))
        guard let currentIndex = spaceIDs.firstIndex(of: currentID) else {
            return nil
        }

        return SpaceTarget(
            displayIdentifier: displayIdentifier,
            currentID: currentID,
            currentIndex: currentIndex,
            spaceIDs: spaceIDs
        )
    }
}
