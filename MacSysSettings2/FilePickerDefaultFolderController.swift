//
//  FilePickerDefaultFolderController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class FilePickerDefaultFolderController: ObservableObject {
    static let shared = FilePickerDefaultFolderController()

    @Published private(set) var lastStatus = FilePickerDefaultFolderStore.lastStatus

    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var lastAppliedKey = ""
    private var lastAppliedAt = Date.distantPast

    func start() {
        observeChanges()
        syncState()
    }

    private func observeChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: FilePickerDefaultFolderStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncState()
            }
        }
    }

    private func syncState() {
        lastStatus = FilePickerDefaultFolderStore.lastStatus
        if FilePickerDefaultFolderStore.isEnabled {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFrontmostPanel()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func checkFrontmostPanel() {
        guard AXIsProcessTrusted() else {
            return
        }

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleIdentifier = app.bundleIdentifier,
                  let rule = FilePickerDefaultFolderStore.enabledRule(for: bundleIdentifier),
                  FileManager.default.fileExists(atPath: rule.folderPath) else {
                continue
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            let windows = windowsForApp(appElement)
            guard let window = windows.compactMap({ filePickerWindow(in: $0) }).first else {
                continue
            }

            let title = stringAttribute(kAXTitleAttribute as CFString, on: window) ?? "panel"
            let applyKey = "\(app.processIdentifier)-\(title)-\(rule.folderPath)"
            guard applyKey != lastAppliedKey || Date().timeIntervalSince(lastAppliedAt) > 7 else { return }

            lastAppliedKey = applyKey
            lastAppliedAt = Date()
            log("matched \(bundleIdentifier) \(title) -> \(rule.folderPath)")
            jumpFilePicker(bundleIdentifier: bundleIdentifier, folderPath: rule.folderPath)
            return
        }
    }

    private func filePickerWindow(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth <= 5 else { return nil }
        if isFilePickerWindow(element) {
            return element
        }
        guard let children = arrayAttribute(kAXChildrenAttribute as CFString, on: element) else {
            return nil
        }
        for child in children {
            if let match = filePickerWindow(in: child, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private func isFilePickerWindow(_ window: AXUIElement) -> Bool {
        let title = (stringAttribute(kAXTitleAttribute as CFString, on: window) ?? "").lowercased()
        let role = stringAttribute(kAXRoleAttribute as CFString, on: window) ?? ""
        let subrole = stringAttribute(kAXSubroleAttribute as CFString, on: window) ?? ""

        guard role == kAXWindowRole as String || subrole == kAXDialogSubrole as String else {
            return false
        }

        let titleLooksRight = [
            "open",
            "save",
            "choose",
            "upload",
            "select",
            "export",
            "import"
        ].contains { title.contains($0) }

        if titleLooksRight {
            return true
        }

        return hasSheetLikeFileControls(window)
    }

    private func hasSheetLikeFileControls(_ window: AXUIElement) -> Bool {
        let descendants = descendants(of: window, maxDepth: 4)
        let roles = descendants.compactMap { stringAttribute(kAXRoleAttribute as CFString, on: $0) }
        let hasBrowser = roles.contains(kAXBrowserRole as String) || roles.contains(kAXOutlineRole as String) || roles.contains(kAXTableRole as String)
        let hasButtons = roles.contains(kAXButtonRole as String)
        return hasBrowser && hasButtons
    }

    private func descendants(of element: AXUIElement, maxDepth: Int, depth: Int = 0) -> [AXUIElement] {
        guard depth < maxDepth,
              let children = arrayAttribute(kAXChildrenAttribute as CFString, on: element) else {
            return []
        }
        return children + children.flatMap { descendants(of: $0, maxDepth: maxDepth, depth: depth + 1) }
    }

    private func windowsForApp(_ appElement: AXUIElement) -> [AXUIElement] {
        var windows: [AXUIElement] = []

        if let focusedWindow = attribute(kAXFocusedWindowAttribute as CFString, on: appElement) {
            windows.append(focusedWindow)
        }

        if let appWindows = arrayAttribute(kAXWindowsAttribute as CFString, on: appElement) {
            for window in appWindows where !windows.contains(where: { CFEqual($0, window) }) {
                windows.append(window)
            }
        }

        return windows
    }

    private func jumpFilePicker(bundleIdentifier: String, folderPath: String) {
        let escapedBundleIdentifier = bundleIdentifier.appleScriptEscaped
        let escapedPath = folderPath.appleScriptEscaped
        let script = """
        tell application id "\(escapedBundleIdentifier)" to activate
        delay 0.12
        tell application "System Events"
            keystroke "g" using {command down, shift down}
            delay 0.14
            keystroke "\(escapedPath)"
            key code 36
            delay 0.16
            key code 36
        end tell
        """

        var error: NSDictionary?
        if NSAppleScript(source: script)?.executeAndReturnError(&error) != nil {
            FilePickerDefaultFolderStore.setLastStatus("Opened \(URL(fileURLWithPath: folderPath).lastPathComponent)")
        } else {
            FilePickerDefaultFolderStore.setLastStatus("Needs access")
            log("AppleScript failed \(String(describing: error))")
        }
    }

    private func attribute(_ name: CFString, on element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func arrayAttribute(_ name: CFString, on element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success,
              let array = value as? [AXUIElement] else {
            return nil
        }
        return array
    }

    private func stringAttribute(_ name: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? String
    }

    private func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-file-picker-defaults.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
