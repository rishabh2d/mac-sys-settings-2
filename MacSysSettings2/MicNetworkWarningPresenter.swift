//
//  MicNetworkWarningPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import SwiftUI

@MainActor
final class MicNetworkWarningPresenter {
    private let panelSize = NSSize(width: 250, height: 144)
    private var panel: MicNetworkWarningPanel?
    private var dismissTask: Task<Void, Never>?

    func show(detail: String) {
        dismissTask?.cancel()

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: MicNetworkWarningView(
                detail: detail,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        )
        position(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            self?.hide()
        }
    }

    func hide() {
        dismissTask?.cancel()
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanelIfNeeded() -> MicNetworkWarningPanel {
        if let panel {
            return panel
        }

        let panel = MicNetworkWarningPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
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
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.midX - panelSize.width / 2,
                y: screen.visibleFrame.midY - panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            ),
            display: true
        )
    }
}

private final class MicNetworkWarningPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct MicNetworkWarningView: View {
    let detail: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color(red: 0.96, green: 0.17, blue: 0.13))
                    )

                Text("Wi-Fi off for mic!")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.65))
            .padding(10)
        }
        .frame(width: 250, height: 144)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
