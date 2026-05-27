//
//  DownloadsPreviewPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DownloadsPreviewPresenter {
    private let panelSize = NSSize(width: 286, height: 82)
    private var panel: DownloadsPreviewPanel?
    private var dismissTask: Task<Void, Never>?
    private var representedURL: URL?
    private var isHovering = false

    func show(fileURL: URL, on screen: NSScreen? = nil) {
        representedURL = fileURL

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: DownloadsPreviewView(
                fileURL: fileURL,
                onHoverChanged: { [weak self] isHovering in
                    self?.setHovering(isHovering)
                },
                onDragStarted: { [weak self] in
                    self?.scheduleDismiss(after: 2.0)
                }
            )
        )
        position(panel, on: screen)

        dismissTask?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        scheduleDismiss(after: 3.0)
    }

    private func makePanelIfNeeded() -> DownloadsPreviewPanel {
        if let panel {
            return panel
        }

        let panel = DownloadsPreviewPanel(
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
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, on preferredScreen: NSScreen?) {
        let screen = preferredScreen
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.maxX - panelSize.width - 20,
            y: visibleFrame.minY + 20
        )

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func setHovering(_ hovering: Bool) {
        isHovering = hovering

        if hovering {
            dismissTask?.cancel()
        } else {
            scheduleDismiss(after: 2.0)
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

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

private final class DownloadsPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct DownloadsPreviewView: View {
    let fileURL: URL
    let onHoverChanged: (Bool) -> Void
    let onDragStarted: () -> Void

    private var fileName: String {
        fileURL.lastPathComponent
    }

    private var fileSubtitle: String {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values?.fileSize else {
            return "New download"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            FileIconView(fileURL: fileURL)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(fileName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(fileSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(width: 286, height: 82)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover(perform: onHoverChanged)
        .onDrag {
            onDragStarted()
            return NSItemProvider(contentsOf: fileURL) ?? NSItemProvider(object: fileURL as NSURL)
        }
    }
}

private struct FileIconView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSWorkspace.shared.icon(forFile: fileURL.path)
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSWorkspace.shared.icon(forFile: fileURL.path)
    }
}
