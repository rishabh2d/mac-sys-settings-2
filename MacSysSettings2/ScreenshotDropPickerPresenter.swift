//
//  ScreenshotDropPickerPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/27/26.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class ScreenshotDropPickerPresenter {
    private let panelWidth: CGFloat = 128
    private let rowHeight: CGFloat = 44
    private let itemWidth: CGFloat = 48
    private let rowSpacing: CGFloat = 8
    private let columnSpacing: CGFloat = 8
    private let panelPadding: CGFloat = 10
    private let bottomOffset: CGFloat = 132
    private var panel: ScreenshotDropPickerPanel?
    private var dismissTask: Task<Void, Never>?
    private var isHovering = false
    private var currentFileURL: URL?
    private var queuedApp: ScreenshotDropTargetApp?

    func showPending(on screen: NSScreen?) {
        currentFileURL = nil
        render(fileURL: nil, on: screen, dismissAfter: 6.5)
    }

    func show(fileURL: URL, on screen: NSScreen?, dismissAfter: TimeInterval = 6.5) {
        currentFileURL = fileURL
        render(fileURL: fileURL, on: screen, dismissAfter: dismissAfter)
        sendQueuedAppIfNeeded(fileURL: fileURL)
    }

    func attach(fileURL: URL, on screen: NSScreen?, dismissAfter: TimeInterval = 1.5) {
        guard panel?.isVisible == true || queuedApp != nil else {
            return
        }
        currentFileURL = fileURL
        render(fileURL: fileURL, on: screen, dismissAfter: dismissAfter)
        sendQueuedAppIfNeeded(fileURL: fileURL)
    }

    private func sendQueuedAppIfNeeded(fileURL: URL) {
        guard let queuedApp else { return }
        self.queuedApp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.send(fileURL: fileURL, to: queuedApp)
            self?.scheduleDismiss(after: 1.5)
        }
    }

    private func render(fileURL: URL?, on screen: NSScreen?, dismissAfter: TimeInterval) {
        let apps = dropTargets()
        guard !apps.isEmpty else { return }
        let resolvedScreen = preferredScreen(screen)
        let panelSize = size(forItemCount: apps.count + 1, on: resolvedScreen)

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: ScreenshotDropPickerView(
                fileURL: fileURL,
                apps: apps,
                panelHeight: panelSize.height,
                rowHeight: rowHeight,
                itemWidth: itemWidth,
                rowSpacing: rowSpacing,
                columnSpacing: columnSpacing,
                panelPadding: panelPadding,
                onClose: { [weak self] in
                    self?.hide()
                },
                onHoverChanged: { [weak self] hovering in
                    self?.setHovering(hovering)
                },
                onAppClicked: { [weak self] app in
                    self?.handleAppClicked(app)
                },
                onDragStarted: { [weak self] in
                    self?.scheduleDismiss(after: 2.0)
                }
            )
        )
        position(panel, size: panelSize, on: resolvedScreen)

        dismissTask?.cancel()
        let wasVisible = panel.isVisible && panel.alphaValue > 0
        if !wasVisible {
            panel.alphaValue = 0
        }
        panel.orderFrontRegardless()

        if wasVisible {
            panel.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.03
                panel.animator().alphaValue = 1
            }
        }

        scheduleDismiss(after: dismissAfter)
    }

    private func handleAppClicked(_ app: ScreenshotDropTargetApp) {
        guard let currentFileURL else {
            queuedApp = app
            scheduleDismiss(after: 6.5)
            return
        }

        send(fileURL: currentFileURL, to: app)
        scheduleDismiss(after: 1.5)
    }

    private func send(fileURL: URL, to app: ScreenshotDropTargetApp) {
        paste(fileURL: fileURL, into: app)
    }

    private func paste(fileURL: URL, into app: ScreenshotDropTargetApp) {
        writeFileToPasteboard(fileURL)

        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == app.name }) {
            activate(app: runningApp)
        } else if let bundleURL = app.bundleURL {
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration())
        }

        guard app.name.localizedCaseInsensitiveContains("Codex") else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                postCommandV()
            }
            return
        }

        for (index, delay) in [0.30, 0.72, 1.08].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                clickCodexInputArea(processIdentifier: app.processIdentifier)
                if index > 0 {
                    self.writeFileToPasteboard(fileURL)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    postCommandV()
                }
            }
        }
    }

    private func writeFileToPasteboard(_ fileURL: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let image = NSImage(contentsOf: fileURL),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
            pasteboard.setData(tiffData, forType: .tiff)
        }

        pasteboard.setString(fileURL.absoluteString, forType: .fileURL)
        pasteboard.setPropertyList([fileURL.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        pasteboard.writeObjects([fileURL as NSURL])
    }

    private func activate(app: NSRunningApplication) {
        app.unhide()
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    private func makePanelIfNeeded() -> ScreenshotDropPickerPanel {
        if let panel {
            return panel
        }

        let panel = ScreenshotDropPickerPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: panelWidth, height: 316)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.ignoresMouseEvents = false
        self.panel = panel
        return panel
    }

    private func preferredScreen(_ screen: NSScreen?) -> NSScreen? {
        screen
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func size(forItemCount itemCount: Int, on screen: NSScreen?) -> NSSize {
        let desiredHeight = panelPadding * 2
            + CGFloat(Int(ceil(Double(itemCount) / 2.0))) * rowHeight
            + CGFloat(max(0, Int(ceil(Double(itemCount) / 2.0)) - 1)) * rowSpacing

        guard let screen else {
            return NSSize(width: panelWidth, height: min(desiredHeight, 520))
        }

        let visible = screen.visibleFrame
        let maxHeight = max(rowHeight + panelPadding * 2, visible.height - bottomOffset - 14)
        return NSSize(width: panelWidth, height: min(desiredHeight, maxHeight))
    }

    private func position(_ panel: NSPanel, size panelSize: NSSize, on screen: NSScreen?) {
        guard let screen else { return }

        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.maxX - panelSize.width - 18,
            y: frame.minY + bottomOffset
        )
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            dismissTask?.cancel()
        } else {
            scheduleDismiss(after: 1.5)
        }
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        guard !isHovering else { return }
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled, !isHovering else { return }
            hide()
        }
    }

    private func hide() {
        guard let panel else { return }
        queuedApp = nil
        currentFileURL = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func dropTargets() -> [ScreenshotDropTargetApp] {
        let blockedBundleIDs: Set<String> = [
            Bundle.main.bundleIdentifier ?? "",
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.systemuiserver"
        ]

        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    && !app.isTerminated
                    && !app.isHidden
                    && !(app.bundleIdentifier.map { blockedBundleIDs.contains($0) } ?? false)
            }
            .compactMap { app -> ScreenshotDropTargetApp? in
                let key = app.bundleIdentifier ?? app.localizedName ?? "\(app.processIdentifier)"
                guard !seen.contains(key) else { return nil }
                seen.insert(key)
                return ScreenshotDropTargetApp(
                    id: key,
                    name: app.localizedName ?? "App",
                    processIdentifier: app.processIdentifier,
                    bundleURL: app.bundleURL,
                    icon: app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
                )
            }
            .sorted { lhs, rhs in
                if lhs.name == "Codex" { return true }
                if rhs.name == "Codex" { return false }
                if lhs.name == "Google Chrome" { return true }
                if rhs.name == "Google Chrome" { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }
}

private final class ScreenshotDropPickerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct ScreenshotDropTargetApp: Identifiable {
    let id: String
    let name: String
    let processIdentifier: pid_t
    let bundleURL: URL?
    let icon: NSImage
}

private struct ScreenshotDropPickerView: View {
    let fileURL: URL?
    let apps: [ScreenshotDropTargetApp]
    let panelHeight: CGFloat
    let rowHeight: CGFloat
    let itemWidth: CGFloat
    let rowSpacing: CGFloat
    let columnSpacing: CGFloat
    let panelPadding: CGFloat
    let onClose: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onAppClicked: (ScreenshotDropTargetApp) -> Void
    let onDragStarted: () -> Void

    var body: some View {
        let columns = [
            GridItem(.fixed(itemWidth), spacing: columnSpacing),
            GridItem(.fixed(itemWidth), spacing: 0)
        ]
        let content = LazyVGrid(columns: columns, alignment: .center, spacing: rowSpacing) {
            ScreenshotDropCloseRow(itemWidth: itemWidth, rowHeight: rowHeight, onClose: onClose)

            ForEach(apps) { app in
                ScreenshotDropTargetRow(
                    app: app,
                    fileURL: fileURL,
                    itemWidth: itemWidth,
                    rowHeight: rowHeight,
                    onClicked: onAppClicked,
                    onDragStarted: onDragStarted
                )
            }
        }

        Group {
            if contentHeight > panelHeight {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
            } else {
                content
            }
        }
        .padding(panelPadding)
        .frame(width: 128, height: panelHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover(perform: onHoverChanged)
    }

    private var contentHeight: CGFloat {
        let itemCount = apps.count + 1
        let rowCount = Int(ceil(Double(itemCount) / 2.0))
        return panelPadding * 2
            + CGFloat(rowCount) * rowHeight
            + CGFloat(max(0, rowCount - 1)) * rowSpacing
    }
}

private struct ScreenshotDropCloseRow: View {
    let itemWidth: CGFloat
    let rowHeight: CGFloat
    let onClose: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onClose) {
            ZStack {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: itemWidth, height: rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(isHovering ? 0.98 : 0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isHovering ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help("Close")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct ScreenshotDropTargetRow: View {
    let app: ScreenshotDropTargetApp
    let fileURL: URL?
    let itemWidth: CGFloat
    let rowHeight: CGFloat
    let onClicked: (ScreenshotDropTargetApp) -> Void
    let onDragStarted: () -> Void
    @State private var isHovering = false
    @State private var blinkCount = 0

    var body: some View {
        ZStack {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 34, height: 34)
        }
        .frame(width: itemWidth, height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((isHovering || blinkCount > 0) ? Color.white.opacity(0.96) : Color.clear, lineWidth: 2)
        )
        .help(app.name)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            blinkBorderThreeTimes()
            onClicked(app)
        }
        .onDrag {
            guard let fileURL else {
                blinkBorderThreeTimes()
                onClicked(app)
                return NSItemProvider(object: app.name as NSString)
            }
            onDragStarted()
            return NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }

    private func blinkBorderThreeTimes() {
        blinkCount += 1
        for index in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.11)) {
                blinkCount = index.isMultiple(of: 2) ? 1 : 0
            }
        }
    }
}

private func postCommandV() {
    guard let source = CGEventSource(stateID: .hidSystemState) else { return }
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

private func clickCodexInputArea(processIdentifier: pid_t) {
    guard let frame = focusedWindowFrame(processIdentifier: processIdentifier) ?? frontWindowFrame(processIdentifier: processIdentifier) else { return }
    let point = CGPoint(x: frame.midX, y: frame.maxY - 74)
    postMouseClick(at: point)
}

private func focusedWindowFrame(processIdentifier: pid_t) -> CGRect? {
    let appElement = AXUIElementCreateApplication(processIdentifier)
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
          let window = value else {
        return nil
    }

    var positionValue: AnyObject?
    var sizeValue: AnyObject?
    guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &positionValue) == .success,
          AXUIElementCopyAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
          let position = positionValue,
          let size = sizeValue else {
        return nil
    }

    var point = CGPoint.zero
    var cgSize = CGSize.zero
    AXValueGetValue(position as! AXValue, .cgPoint, &point)
    AXValueGetValue(size as! AXValue, .cgSize, &cgSize)
    return CGRect(origin: point, size: cgSize)
}

private func frontWindowFrame(processIdentifier: pid_t) -> CGRect? {
    guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    for window in windowList {
        guard (window[kCGWindowOwnerPID as String] as? pid_t) == processIdentifier,
              (window[kCGWindowLayer as String] as? Int) == 0,
              let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"],
              let y = bounds["Y"],
              let width = bounds["Width"],
              let height = bounds["Height"],
              width > 160,
              height > 160 else {
            continue
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    return nil
}

private func postMouseClick(at point: CGPoint) {
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(25_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(35_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
}
