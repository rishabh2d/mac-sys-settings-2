//
//  CenteredHUDPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 07/04/26.
//

import AppKit
import SwiftUI

@MainActor
final class CenteredHUDPresenter {
    enum Kind {
        case paused
        case played

        var iconName: String {
            switch self {
            case .paused:
                return "pause.fill"
            case .played:
                return "play.fill"
            }
        }

        var label: String {
            switch self {
            case .paused:
                return "Paused"
            case .played:
                return "Played"
            }
        }
    }

    private let panelSize = NSSize(width: 168, height: 168)
    private var panel: PassiveHUDPanel?
    private var dismissTask: Task<Void, Never>?

    func show(_ kind: Kind) {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(rootView: CenteredHUDView(kind: kind))
        center(panel: panel)

        dismissTask?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self, !Task.isCancelled else { return }
            hide(panel: panel)
        }
    }

    private func makePanelIfNeeded() -> PassiveHUDPanel {
        if let panel {
            return panel
        }

        let panel = PassiveHUDPanel(
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func center(panel: NSPanel) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }

        let origin = NSPoint(
            x: screen.frame.midX - (panelSize.width / 2),
            y: screen.frame.midY - (panelSize.height / 2)
        )

        panel.setFrameOrigin(origin)
    }

    private func hide(panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

private final class PassiveHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct CenteredHUDView: View {
    let kind: CenteredHUDPresenter.Kind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                }

            VStack(spacing: 10) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Text(kind.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray.opacity(0.95))
            }
            .padding(.top, 4)
        }
        .frame(width: 168, height: 168)
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
    }
}
