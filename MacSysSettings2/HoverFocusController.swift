//
//  HoverFocusController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class HoverFocusController: ObservableObject {
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var pendingWindow: HoverWindow?
    private var pendingSince = Date.distantPast
    private var lastFocusedWindowKey = ""
    private let hoverDelay: TimeInterval = 0.055
    private let pollInterval: TimeInterval = 0.035

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: HoverFocusStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncState()
            }
        }
        syncState()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        timer?.invalidate()
    }

    private func syncState() {
        if HoverFocusStore.isEnabled {
            requestAccessibilityAccess()
            startPolling()
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollHover()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        pendingWindow = nil
        pendingSince = .distantPast
    }

    private func pollHover() {
        guard HoverFocusStore.isEnabled else {
            stopPolling()
            return
        }

        guard AXIsProcessTrusted() else {
            return
        }

        guard let hoveredWindow = windowUnderMouse() else {
            pendingWindow = nil
            return
        }

        if hoveredWindow.key == lastFocusedWindowKey {
            return
        }

        if pendingWindow?.key != hoveredWindow.key {
            pendingWindow = hoveredWindow
            pendingSince = Date()
            return
        }

        guard Date().timeIntervalSince(pendingSince) >= hoverDelay else { return }
        focus(hoveredWindow)
    }

    private func windowUnderMouse() -> HoverWindow? {
        guard let mouseLocation = CGEvent(source: nil)?.location else {
            return nil
        }

        if let accessibilityWindow = accessibilityWindowUnderMouse(mouseLocation) {
            return accessibilityWindow
        }

        return visibleWindowUnderMouse(mouseLocation)
    }

    private func focus(_ hoverWindow: HoverWindow) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == hoverWindow.processIdentifier && !$0.isTerminated
        }) else {
            return
        }

        let appElement = AXUIElementCreateApplication(hoverWindow.processIdentifier)
        let window = hoverWindow.window ?? matchingWindow(for: appElement, frame: hoverWindow.frame)
        guard let window else { return }

        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window)
        setBool(true, attribute: kAXMainAttribute, on: window)
        setBool(true, attribute: kAXFocusedAttribute, on: window)
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        lastFocusedWindowKey = hoverWindow.key
    }

    private func accessibilityWindowUnderMouse(_ mouseLocation: CGPoint) -> HoverWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(mouseLocation.y), &element) == .success,
              let element,
              let window = containingWindow(for: element) else {
            return nil
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success,
              pid > 0,
              pid != getpid(),
              let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window),
              size.width >= 80,
              size.height >= 60 else {
            return nil
        }

        return HoverWindow(
            processIdentifier: pid,
            windowNumber: 0,
            frame: CGRect(origin: position, size: size),
            window: window,
            hoveredElement: element
        )
    }

    private func containingWindow(for element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element

        for _ in 0..<8 {
            guard let candidate = current else { return nil }

            if role(of: candidate) == kAXWindowRole as String {
                return candidate
            }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parent) == .success,
                  let parentElement = parent,
                  CFGetTypeID(parentElement) == AXUIElementGetTypeID() else {
                return nil
            }

            current = (parentElement as! AXUIElement)
        }

        return nil
    }

    private func visibleWindowUnderMouse(_ mouseLocation: CGPoint) -> HoverWindow? {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        return rawWindows.compactMap { info -> HoverWindow? in
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0 else { return nil }

            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != getpid(),
                  let windowNumber = info[kCGWindowNumber as String] as? Int,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: boundsDictionary),
                  frame.width >= 80,
                  frame.height >= 60,
                  frame.contains(mouseLocation) else {
                return nil
            }

            return HoverWindow(processIdentifier: ownerPID, windowNumber: windowNumber, frame: frame, window: nil, hoveredElement: nil)
        }.first
    }

    private func matchingWindow(for appElement: AXUIElement, frame: CGRect) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.first { candidate in
            guard let position = windowPoint(candidate, attribute: kAXPositionAttribute),
                  let size = windowSize(candidate) else { return false }
            return framesAreClose(CGRect(origin: position, size: size), frame)
        }
    }

    private func windowPoint(_ window: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue((axValue as! AXValue), .cgPoint, &point) else { return nil }
        return point
    }

    private func windowSize(_ window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue((axValue as! AXValue), .cgSize, &size) else { return nil }
        return size
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        if let stringValue = value as? String {
            return stringValue
        }

        return (value as? NSObject)?.description
    }

    private func setBool(_ bool: Bool, attribute: String, on element: AXUIElement) {
        let value = bool as CFBoolean
        _ = AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    private func framesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 10
            && abs(lhs.minY - rhs.minY) <= 10
            && abs(lhs.width - rhs.width) <= 20
            && abs(lhs.height - rhs.height) <= 20
    }

    private func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private struct HoverWindow {
        let processIdentifier: pid_t
        let windowNumber: Int
        let frame: CGRect
        let window: AXUIElement?
        let hoveredElement: AXUIElement?

        var key: String {
            "\(processIdentifier)-\(windowNumber)-\(Int(frame.minX))-\(Int(frame.minY))-\(Int(frame.width))-\(Int(frame.height))"
        }
    }
}
