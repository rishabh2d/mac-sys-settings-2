//
//  WindowLayoutStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import ApplicationServices
import Foundation

enum LayoutPresetName: String, CaseIterable, Identifiable, Codable {
    case coding = "Coding"
    case research = "Research"
    case meeting = "Meeting"

    var id: String { rawValue }
}

enum LayoutScreenTarget: String, CaseIterable, Identifiable, Codable {
    case main = "Main"
    case external = "External"
    case any = "Any"

    var id: String { rawValue }
}

enum LayoutPosition: String, CaseIterable, Identifiable, Codable {
    case left = "Left"
    case right = "Right"
    case center = "Center"
    case fullscreen = "Fullscreen"

    var id: String { rawValue }
}

enum LayoutSize: String, CaseIterable, Identifiable, Codable {
    case half = "Half"
    case third = "One Third"
    case twoThirds = "Two Thirds"
    case full = "Full"

    var id: String { rawValue }
}

struct WindowLayoutRule: Identifiable, Equatable, Codable {
    var id = UUID()
    var appName: String
    var screen: LayoutScreenTarget
    var position: LayoutPosition
    var size: LayoutSize
}

struct WindowMode: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: LayoutPresetName
    var rules: [WindowLayoutRule]
}

enum WindowLayoutStore {
    static let didChangeNotification = Notification.Name("WindowLayoutModesDidChange")
    private static let defaultsKey = "window.modes.v1"
    static let modeShortcutText = "Control-Option-Command-M"
    static let appChoices = ["Google Chrome", "Cursor", "Notes", "Slack", "Finder", "Terminal", "Xcode", "Messages", "Calendar", "Mail", "Wispr Flow"]
    private static let bundleIdentifiersByAppName = [
        "Cursor": "com.todesktop.230313mzl4w4u92",
        "Google Chrome": "com.google.Chrome",
        "Notes": "com.apple.Notes",
        "Slack": "com.tinyspeck.slackmacgap",
        "Finder": "com.apple.finder",
        "Terminal": "com.apple.Terminal",
        "Xcode": "com.apple.dt.Xcode",
        "Messages": "com.apple.MobileSMS",
        "Calendar": "com.apple.iCal",
        "Mail": "com.apple.mail"
    ]

    static func loadModes() -> [WindowMode] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let modes = try? JSONDecoder().decode([WindowMode].self, from: data),
              !modes.isEmpty else {
            return defaultModes()
        }

        return modes
    }

    static func saveModes(_ modes: [WindowMode]) {
        if let data = try? JSONEncoder().encode(modes) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    static func defaultModes() -> [WindowMode] {
        LayoutPresetName.allCases.map { preset in
            WindowMode(name: preset, rules: defaultRules(for: preset))
        }
    }

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
    static func apply(_ rules: [WindowLayoutRule], overrideScreen: NSScreen? = nil) -> [String] {
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

            let frame = frameForRule(rule, overrideScreen: overrideScreen)
            setWindow(window, frame: frame)
            return "\(rule.appName): applied"
        }
    }

    static func activate(_ mode: WindowMode, targetScreen: NSScreen? = nil) async -> [String] {
        guard ensureAccessibilityAccess() else {
            return ["Accessibility permission is required."]
        }

        let launchResults = mode.rules.map { launchAppIfNeeded(named: $0.appName) }

        for attempt in 0..<12 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 550_000_000)
            }

            let results = apply(mode.rules, overrideScreen: targetScreen)
            if results.allSatisfy({ !$0.contains("not running") && !$0.contains("no window") }) {
                return launchResults + results
            }

            nudgeMissingWindows(for: mode.rules, from: results)
        }

        return launchResults + apply(mode.rules, overrideScreen: targetScreen)
    }

    private static func ensureAccessibilityAccess() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func launchAppIfNeeded(named name: String) -> String {
        if runningApplication(named: name) != nil {
            return "\(name): already open"
        }

        if openApplication(named: name) {
            return "\(name): opening"
        }

        return "\(name): not found"
    }

    @discardableResult
    private static func openApplication(named name: String) -> Bool {
        if let bundleIdentifier = bundleIdentifiersByAppName[name],
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.open(url)
            return true
        }

        for baseURL in [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")] {
            let url = baseURL.appendingPathComponent("\(name).app")
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.open(url)
                return true
            }
        }

        if name == "Finder", let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            NSWorkspace.shared.open(url)
            return true
        }

        return false
    }

    private static func nudgeMissingWindows(for rules: [WindowLayoutRule], from results: [String]) {
        for (rule, result) in zip(rules, results) {
            guard result.contains("not running") || result.contains("no window") else {
                continue
            }

            if let app = runningApplication(named: rule.appName) {
                app.activate(options: [.activateIgnoringOtherApps])
            }

            openApplication(named: rule.appName)
        }
    }

    private static func runningApplication(named name: String) -> NSRunningApplication? {
        if let bundleIdentifier = bundleIdentifiersByAppName[name],
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app
        }

        return NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "").localizedCaseInsensitiveCompare(name) == .orderedSame
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

    private static func frameForRule(_ rule: WindowLayoutRule, overrideScreen: NSScreen? = nil) -> CGRect {
        let screen = overrideScreen ?? targetScreen(for: rule) ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = accessibilityScreenFrame(for: screen)
        let height = rounded(frame.height)

        switch rule.position {
        case .left:
            switch rule.size {
            case .third:
                return CGRect(x: rounded(frame.minX), y: rounded(frame.minY), width: leftSplitWidth(fraction: 1.0 / 3.0, in: frame), height: height)
            case .twoThirds:
                return CGRect(x: rounded(frame.minX), y: rounded(frame.minY), width: leftSplitWidth(fraction: 2.0 / 3.0, in: frame), height: height)
            default:
                let width = rounded(widthForSize(rule.size, in: frame))
                return CGRect(x: rounded(frame.minX), y: rounded(frame.minY), width: width, height: height)
            }
        case .right:
            switch rule.size {
            case .third:
                let splitX = rounded(frame.minX + floor(frame.width * 2.0 / 3.0))
                return CGRect(x: splitX, y: rounded(frame.minY), width: rounded(frame.maxX - splitX), height: height)
            case .twoThirds:
                let splitX = rounded(frame.minX + floor(frame.width / 3.0))
                return CGRect(x: splitX, y: rounded(frame.minY), width: rounded(frame.maxX - splitX), height: height)
            default:
                let width = rounded(widthForSize(rule.size, in: frame))
                return CGRect(x: rounded(frame.maxX - width), y: rounded(frame.minY), width: width, height: height)
            }
        case .center:
            let width = rounded(widthForSize(rule.size, in: frame))
            return CGRect(x: rounded(frame.midX - (width / 2)), y: rounded(frame.minY), width: width, height: height)
        case .fullscreen:
            return CGRect(x: rounded(frame.minX), y: rounded(frame.minY), width: rounded(frame.width), height: height)
        }
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

    static func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
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

    private static func leftSplitWidth(fraction: CGFloat, in frame: CGRect) -> CGFloat {
        rounded(floor(frame.width * fraction))
    }

    private static func rounded(_ value: CGFloat) -> CGFloat {
        value.rounded(.toNearestOrAwayFromZero)
    }

    private static func accessibilityScreenFrame(for screen: NSScreen) -> CGRect {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return CGRect(
                x: screen.visibleFrame.minX,
                y: screen.frame.maxY - screen.visibleFrame.maxY,
                width: screen.visibleFrame.width,
                height: screen.visibleFrame.height
            )
        }

        let displayBounds = CGDisplayBounds(screenNumber)
        let topInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let usableTop = displayBounds.minY + topInset
        let usableBottom = displayBounds.maxY
        let usableHeight = max(120, usableBottom - usableTop)

        return CGRect(
            x: screen.visibleFrame.minX,
            y: usableTop,
            width: screen.visibleFrame.width,
            height: usableHeight
        )
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
