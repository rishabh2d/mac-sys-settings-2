//
//  ModeChooserPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import SwiftUI

@MainActor
final class ModeChooserPresenter {
    private let panelSize = NSSize(width: 420, height: 250)
    private var panel: ModeChooserPanel?

    func show(onSelect: @escaping (WindowMode) -> Void) {
        let modes = WindowLayoutStore.loadModes()
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: ModeChooserView(modes: modes) { [weak self] mode in
                self?.hide()
                onSelect(mode)
            } onCancel: { [weak self] in
                self?.hide()
            }
        )
        center(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
    }

    private func makePanelIfNeeded() -> ModeChooserPanel {
        if let panel {
            return panel
        }

        let panel = ModeChooserPanel(
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
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func center(panel: NSPanel) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }

        panel.setFrame(
            NSRect(
                x: screen.frame.midX - panelSize.width / 2,
                y: screen.frame.midY - panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            ),
            display: true
        )
    }

    private func hide() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

private final class ModeChooserPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct ModeChooserView: View {
    let modes: [WindowMode]
    let onSelect: (WindowMode) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose Mode")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Open apps and place them on the saved monitors.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.86))
            }

            VStack(spacing: 9) {
                ForEach(modes) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.3.group.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.name.rawValue)
                                    .font(.system(size: 14.5, weight: .semibold))
                                Text(mode.rules.map(\.appName).joined(separator: ", "))
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.62))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.13))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(width: 420, height: 250)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.86))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
