//
//  WindowLayoutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import ApplicationServices
import Foundation

enum LayoutPresetName: String, CaseIterable, Identifiable {
    case coding = "Coding"
    case research = "Research"
    case meeting = "Meeting"

    var id: String { rawValue }
}

enum LayoutScreenTarget: String, CaseIterable, Identifiable {
    case main = "Main"
    case external = "External"
    case any = "Any"

    var id: String { rawValue }
}

enum LayoutPosition: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case center = "Center"
    case fullscreen = "Fullscreen"

    var id: String { rawValue }
}

enum LayoutSize: String, CaseIterable, Identifiable {
    case half = "Half"
    case third = "One Third"
    case twoThirds = "Two Thirds"
    case full = "Full"

    var id: String { rawValue }
}

struct WindowLayoutRule: Identifiable, Equatable {
    let id = UUID()
    var appName: String
    var screen: LayoutScreenTarget
    var position: LayoutPosition
    var size: LayoutSize
}

enum WindowLayoutStore {
    static let appChoices = ["Google Chrome", "Cursor", "Notes", "Slack", "Finder", "Wispr Flow"]

    static func defaultRules(for preset: LayoutPresetName) -> [WindowLayoutRule] {
        switch preset {
        case .coding:
            return [
                WindowLayoutRule(appName: "Cursor", screen: .main, position: .left, size: .twoThirds),
                WindowLayoutRule(appName: "Google Chrome", screen: .main, position: .right, size: .third)
            ]
        case .research:
            return [
                WindowLayoutRule(appName: "Google Chrome", screen: .main, position: .left, size: .twoThirds),
                WindowLayoutRule(appName: "Notes", screen: .main, position: .right, size: .third)
            ]
        case .meeting:
            return [
                WindowLayoutRule(appName: "Google Chrome", screen: .main, position: .fullscreen, size: .full),
                WindowLayoutRule(appName: "Notes", screen: .main, position: .right, size: .third)
            ]
        }
    }

    @discardableResult
    static func apply(_ rules: [WindowLayoutRule]) -> [String] {
        guard AXIsProcessTrusted() else {
            return ["Accessibility permission is required."]
        }

        return rules.map { rule in
            guard let app = runningApplication(named: rule.appName) else {
                return "\(rule.appName): not running"
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            guard let window = focusedOrFirstWindow(for: appElement) else {
                return "\(rule.appName): no window"
            }

            let frame = frameForRule(rule)
            setWindow(window, frame: frame)
            return "\(rule.appName): applied"
        }
    }

    private static func runningApplication(named name: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(name)
                || name.localizedCaseInsensitiveContains($0.localizedName ?? "")
        }
    }

    private static func focusedOrFirstWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let window = value {
            return (window as! AXUIElement)
        }

        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement] {
            return windows.first
        }

        return nil
    }

    private static func frameForRule(_ rule: WindowLayoutRule) -> CGRect {
        let screen = targetScreen(for: rule) ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        let width = widthForSize(rule.size, in: frame)
        let height = frame.height
        let x: CGFloat

        switch rule.position {
        case .left:
            x = frame.minX
        case .right:
            x = frame.maxX - width
        case .center:
            x = frame.midX - (width / 2)
        case .fullscreen:
            return frame
        }

        return CGRect(x: x, y: frame.minY, width: width, height: height)
    }

    private static func targetScreen(for rule: WindowLayoutRule) -> NSScreen? {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        switch rule.screen {
        case .main:
            return NSScreen.main ?? screens.first
        case .external:
            return screens.first { $0 != NSScreen.main } ?? screens.first
        case .any:
            return NSScreen.main ?? screens.first
        }
    }

    private static func widthForSize(_ size: LayoutSize, in frame: CGRect) -> CGFloat {
        switch size {
        case .half:
            return frame.width / 2
        case .third:
            return frame.width / 3
        case .twoThirds:
            return frame.width * 2 / 3
        case .full:
            return frame.width
        }
    }

    private static func setWindow(_ window: AXUIElement, frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return
        }

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }
}
