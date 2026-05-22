//
//  CursorJumpOverlayPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon
import SwiftUI

enum CursorJumpStep {
    case monitor
    case point(monitorNumber: Int)
}

@MainActor
final class CursorJumpOverlayPresenter {
    private let panelSize = NSSize(width: 500, height: 270)
    private var panel: CursorJumpPanel?

    func show(step: CursorJumpStep, onDigit: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        let panel = makePanelIfNeeded()
        panel.onDigit = onDigit
        panel.onCancel = onCancel
        panel.contentView = NSHostingView(rootView: CursorJumpOverlayView(step: step, onDigit: onDigit, onCancel: onCancel))
        center(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        panel.onDigit = nil
        panel.onCancel = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanelIfNeeded() -> CursorJumpPanel {
        if let panel {
            return panel
        }

        let panel = CursorJumpPanel(
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
}

private final class CursorJumpPanel: NSPanel {
    var onDigit: ((Int) -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let digit = Int(characters),
              (0...9).contains(digit) else {
            super.keyDown(with: event)
            return
        }

        onDigit?(digit)
    }
}

private struct CursorJumpOverlayView: View {
    let step: CursorJumpStep
    let onDigit: (Int) -> Void
    let onCancel: () -> Void

    var body: some View {
        if case .monitor = step {
            monitorPicker
        } else {
            pointPicker
        }
    }

    private var monitorPicker: some View {
        HStack(spacing: 34) {
            monitorButton(number: 1, title: "Mac", subtitle: "Built-in display")
            monitorButton(number: 2, title: "External", subtitle: "Second display")
        }
        .padding(18)
        .frame(width: 430, height: 230)
        .background(Color.clear)
    }

    private var pointPicker: some View {
        pointGrid
            .padding(14)
        .frame(width: 500, height: 270)
        .background(Color.clear)
    }

    private var title: String {
        switch step {
        case .monitor:
            return "Jump Cursor"
        case .point(let monitorNumber):
            return "Monitor \(monitorNumber)"
        }
    }

    private var subtitle: String {
        switch step {
        case .monitor:
            return "Press 1 for Mac screen or 2 for external, then press a point number."
        case .point:
            return "Press 1-9 by screen position. 5 is center; 0 also works as center."
        }
    }

    private func monitorButton(number: Int, title: String, subtitle: String) -> some View {
        HoverNumberButton(action: { onDigit(number) }) {
            VStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 74, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 140, height: 196)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
        }
    }

    private var pointGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                pointButton(1, "Top Left")
                pointButton(2, "Top")
                pointButton(3, "Top Right")
            }
            HStack(spacing: 8) {
                pointButton(4, "Left")
                pointButton(5, "Center")
                pointButton(6, "Right")
            }
            HStack(spacing: 8) {
                pointButton(7, "Bottom Left")
                pointButton(8, "Bottom")
                pointButton(9, "Bottom Right")
            }
        }
    }

    private func pointButton(_ number: Int, _ label: String) -> some View {
        HoverNumberButton(action: { onDigit(number) }) {
            Text("\(number)")
                .font(.system(size: 34, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
                .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black.opacity(0.20))
            )
        }
    }
}

private struct HoverNumberButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovering ? 0.95 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
