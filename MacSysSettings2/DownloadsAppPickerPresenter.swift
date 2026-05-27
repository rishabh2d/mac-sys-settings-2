//
//  DownloadsAppPickerPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/27/26.
//

import AppKit
import SwiftUI

@MainActor
final class DownloadsAppPickerPresenter {
    private let panelSize = NSSize(width: 252, height: 338)
    private let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    private var panel: DownloadsAppPickerPanel?
    private var monitorTask: Task<Void, Never>?

    func show(fallbackFileURL: URL, finderFrame: NSRect, on screen: NSScreen?) {
        let apps = appTargets()
        guard !apps.isEmpty else { return }

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: DownloadsAppPickerView(
                fallbackFileURL: fallbackFileURL,
                apps: apps,
                selectedURLs: { [weak self] in
                    self?.selectedDownloadsItems(fallback: fallbackFileURL) ?? [fallbackFileURL]
                },
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        )

        position(panel, beside: finderFrame, on: screen)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }

        startMonitoringDownloadsWindow()
    }

    func hide() {
        monitorTask?.cancel()
        monitorTask = nil

        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanelIfNeeded() -> DownloadsAppPickerPanel {
        if let panel {
            return panel
        }

        let panel = DownloadsAppPickerPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
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

    private func position(_ panel: NSPanel, beside finderFrame: NSRect, on preferredScreen: NSScreen?) {
        let screen = preferredScreen
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let visible = screen.visibleFrame
        var x = finderFrame.minX - panelSize.width - 10
        var y = finderFrame.minY

        if x < visible.minX + 12 {
            x = min(visible.maxX - panelSize.width - 12, finderFrame.minX)
            y = min(visible.maxY - panelSize.height - 12, finderFrame.maxY + 10)
        }

        panel.setFrame(
            NSRect(
                x: max(visible.minX + 12, min(x, visible.maxX - panelSize.width - 12)),
                y: max(visible.minY + 12, min(y, visible.maxY - panelSize.height - 12)),
                width: panelSize.width,
                height: panelSize.height
            ),
            display: true
        )
    }

    private func appTargets() -> [DownloadsAppTarget] {
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
                    && app.bundleURL != nil
                    && !(app.bundleIdentifier.map { blockedBundleIDs.contains($0) } ?? false)
            }
            .compactMap { app -> DownloadsAppTarget? in
                let key = app.bundleIdentifier ?? app.localizedName ?? "\(app.processIdentifier)"
                guard !seen.contains(key), let bundleURL = app.bundleURL else { return nil }
                seen.insert(key)
                return DownloadsAppTarget(
                    id: key,
                    name: app.localizedName ?? "App",
                    bundleURL: bundleURL,
                    icon: NSWorkspace.shared.icon(forFile: bundleURL.path)
                )
            }
            .sorted { lhs, rhs in
                if lhs.name == "Codex" { return true }
                if rhs.name == "Codex" { return false }
                if lhs.name == "Google Chrome" { return true }
                if rhs.name == "Google Chrome" { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(9)
            .map { $0 }
    }

    private func selectedDownloadsItems(fallback: URL) -> [URL] {
        let script = """
        tell application "Finder"
            set output to ""
            try
                if not (exists front Finder window) then return ""
                if POSIX path of (target of front Finder window as alias) does not end with "/Downloads/" then return ""
                set pickedItems to selection
                repeat with pickedItem in pickedItems
                    try
                        set output to output & POSIX path of (pickedItem as alias) & linefeed
                    end try
                end repeat
            end try
            return output
        end tell
        """

        let selected = runAppleScript(script)
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
            .filter { $0.path.hasPrefix(downloadsURL.path + "/") }

        return selected.isEmpty ? [fallback] : selected
    }

    private func startMonitoringDownloadsWindow() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard let self, !Task.isCancelled else { return }
                if !hasDownloadsFinderWindow() {
                    hide()
                    return
                }
            }
        }
    }

    private func hasDownloadsFinderWindow() -> Bool {
        let script = """
        tell application "Finder"
            try
                repeat with finderWindow in Finder windows
                    if POSIX path of (target of finderWindow as alias) ends with "/Downloads/" then return "yes"
                end repeat
            end try
        end tell
        return "no"
        """
        return runAppleScript(script).trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
    }

    private func runAppleScript(_ script: String) -> String {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let result = appleScript.executeAndReturnError(&error).stringValue else {
            return ""
        }
        return result
    }
}

private final class DownloadsAppPickerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct DownloadsAppTarget: Identifiable {
    let id: String
    let name: String
    let bundleURL: URL
    let icon: NSImage
}

private struct DownloadsAppPickerView: View {
    let fallbackFileURL: URL
    let apps: [DownloadsAppTarget]
    let selectedURLs: () -> [URL]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Download")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(fallbackFileURL.lastPathComponent)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 6)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.86))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.13))
                )
                .contentShape(Rectangle())
            }

            VStack(spacing: 6) {
                ForEach(apps) { app in
                    DownloadsAppTargetRow(app: app, selectedURLs: selectedURLs)
                }
            }
        }
        .padding(14)
        .frame(width: 252, height: 338, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.93))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DownloadsAppTargetRow: View {
    let app: DownloadsAppTarget
    let selectedURLs: () -> [URL]

    var body: some View {
        Button {
            NSWorkspace.shared.open(
                selectedURLs(),
                withApplicationAt: app.bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(app.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrowshape.turn.up.right.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.11))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
