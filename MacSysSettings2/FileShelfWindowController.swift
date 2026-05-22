//
//  FileShelfWindowController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FileShelfWindowController {
    private let panelSize = NSSize(width: 390, height: 220)
    private var panel: FileShelfPanel?
    private var emptyCloseTask: Task<Void, Never>?

    func show() {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(rootView: FileShelfView(onClose: { [weak self] in
            self?.hide()
        }))
        position(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        scheduleEmptyCloseIfNeeded()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        emptyCloseTask?.cancel()
        emptyCloseTask = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func makePanelIfNeeded() -> FileShelfPanel {
        if let panel {
            return panel
        }

        let panel = FileShelfPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func position(panel: NSPanel) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }
        let margin: CGFloat = 22
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.maxX - panelSize.width - margin,
                y: screen.visibleFrame.midY - panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            ),
            display: true
        )
    }

    private func scheduleEmptyCloseIfNeeded() {
        emptyCloseTask?.cancel()
        guard FileShelfStore.currentURLs().isEmpty else { return }

        emptyCloseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await MainActor.run {
                guard FileShelfStore.currentURLs().isEmpty else { return }
                self?.hide()
            }
        }
    }
}

private final class FileShelfPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct FileShelfView: View {
    let onClose: () -> Void
    @State private var urls = FileShelfStore.currentURLs()
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shelf")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Drop files here, then drag them out later.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.66))
                }

                Spacer()

                Button {
                    FileShelfStore.clear()
                    reload()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.82))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.88))
            }

            Group {
                if urls.isEmpty {
                    emptyDropZone
                } else {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(urls, id: \.path) { url in
                                shelfItem(url)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isTargeted ? 0.16 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(isTargeted ? 0.55 : 0.18), lineWidth: 1)
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        }
        .padding(14)
        .frame(width: 390, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.70))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: FileShelfStore.didItemsChangeNotification)) { _ in
            reload()
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: 9) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
            Text("Drop files")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shelfItem(_ url: URL) -> some View {
        HStack(spacing: 9) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().lastPathComponent)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))

            Button {
                FileShelfStore.removeURL(url)
                reload()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .onDrag {
            NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url.path as NSString)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var didLoad = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            didLoad = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let itemURL = item as? URL {
                    url = itemURL
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                guard let url else { return }
                Task { @MainActor in
                    FileShelfStore.addURLs([url])
                    reload()
                }
            }
        }
        return didLoad
    }

    private func reload() {
        urls = FileShelfStore.currentURLs()
    }
}
