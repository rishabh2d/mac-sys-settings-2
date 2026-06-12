//
//  CursorJumpOverlayPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon
import Combine
import SwiftUI

enum CursorJumpStep {
    case monitor
    case point(monitorNumber: Int)
    case nudge(monitorNumber: Int)
}

@MainActor
final class CursorJumpOverlayPresenter {
    private let panelSize = NSSize(width: 500, height: 270)
    private let state = CursorJumpOverlayState()
    private var panel: CursorJumpPanel?

    func show(
        step: CursorJumpStep,
        onDigit: @escaping (Int) -> Void,
        onShortcutKey: @escaping (String) -> Bool,
        onMove: @escaping (CGSize) -> Void,
        onCommit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        let panel = makePanelIfNeeded()
        panel.onDigit = onDigit
        panel.onShortcutKey = onShortcutKey
        panel.onMove = onMove
        panel.onCommit = onCommit
        panel.onCancel = onCancel
        panel.contentView = NSHostingView(
            rootView: CursorJumpOverlayView(
                step: step,
                state: state,
                onDigit: onDigit,
                onMove: onMove,
                onCommit: onCommit,
                onCancel: onCancel
            )
        )
        center(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            panel.animator().alphaValue = 1
        }
    }

    func flashMonitor(_ number: Int) {
        state.highlightedMonitorNumber = number
        Task { @MainActor [weak state] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if state?.highlightedMonitorNumber == number {
                state?.highlightedMonitorNumber = nil
            }
        }
    }

    func hide() {
        guard let panel else { return }
        panel.onDigit = nil
        panel.onShortcutKey = nil
        panel.onMove = nil
        panel.onCommit = nil
        panel.onCancel = nil
        panel.isSpaceHeld = false

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

private final class CursorJumpOverlayState: ObservableObject {
    @Published var highlightedMonitorNumber: Int?
}

private final class CursorJumpPanel: NSPanel {
    var onDigit: ((Int) -> Void)?
    var onShortcutKey: ((String) -> Bool)?
    var onMove: ((CGSize) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var isSpaceHeld = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        if event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
            onCommit?()
            return
        }

        if event.keyCode == UInt16(kVK_Space) {
            isSpaceHeld = true
            return
        }

        if isSpaceHeld, handleSpaceMovement(event) {
            return
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters.count == 1 else {
            super.keyDown(with: event)
            return
        }

        if let digit = Int(characters), (0...9).contains(digit) {
            onDigit?(digit)
            return
        }

        if onShortcutKey?(characters.lowercased()) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Space) {
            isSpaceHeld = false
            return
        }

        super.keyUp(with: event)
    }

    private func handleSpaceMovement(_ event: NSEvent) -> Bool {
        let nudge: CGFloat = 28
        let jump: CGFloat = 170

        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            onMove?(CGSize(width: -nudge, height: 0))
            return true
        case kVK_RightArrow:
            onMove?(CGSize(width: nudge, height: 0))
            return true
        case kVK_UpArrow:
            onMove?(CGSize(width: 0, height: -nudge))
            return true
        case kVK_DownArrow:
            onMove?(CGSize(width: 0, height: nudge))
            return true
        default:
            break
        }

        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              characters.count == 1 else {
            return false
        }

        switch characters {
        case "a":
            onMove?(CGSize(width: -jump, height: 0))
            return true
        case "d":
            onMove?(CGSize(width: jump, height: 0))
            return true
        case "w":
            onMove?(CGSize(width: 0, height: -jump))
            return true
        case "s":
            onMove?(CGSize(width: 0, height: jump))
            return true
        default:
            return false
        }
    }
}

private struct CursorJumpOverlayView: View {
    let step: CursorJumpStep
    @ObservedObject var state: CursorJumpOverlayState
    let onDigit: (Int) -> Void
    let onMove: (CGSize) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        switch step {
        case .monitor:
            monitorPicker
        case .point:
            pointPicker
        case .nudge:
            nudgePicker
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

    private var nudgePicker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 9) {
                nudgeArrowTile("←", action: { onMove(CGSize(width: -28, height: 0)) })
                nudgeArrowTile("↑", action: { onMove(CGSize(width: 0, height: -28)) })
                nudgeArrowTile("↓", action: { onMove(CGSize(width: 0, height: 28)) })
                nudgeArrowTile("→", action: { onMove(CGSize(width: 28, height: 0)) })
            }

            nudgeSpacebar
        }
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
        case .nudge:
            return "Nudge Mode"
        }
    }

    private var subtitle: String {
        switch step {
        case .monitor:
            return "Press 1 or 2, or use QWE/ASD/ZXC and UIO/JKL/NM,."
        case .point:
            return "Press 1-9 by screen position, or use the tiny letter under each point."
        case .nudge:
            return "Hold Space with arrows to nudge, Space with WASD for bigger moves."
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
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(state.highlightedMonitorNumber == number ? 0.96 : 0), lineWidth: 4)
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
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.system(size: 31, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(shortcutLabel(for: number))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black.opacity(0.20))
            )
        }
    }

    private func nudgeArrowTile(_ arrow: String, action: @escaping () -> Void) -> some View {
        HoverNumberButton(action: action) {
            Text(arrow)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            .frame(width: 84, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.88), lineWidth: 2)
            )
        }
    }

    private var nudgeSpacebar: some View {
        ZStack {
            Text("Spacebar")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            HStack {
                Spacer()
                Text("↵")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.trailing, 18)
            }
        }
        .frame(width: 384, height: 46)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.white.opacity(0.88), lineWidth: 2)
        )
    }

    private func shortcutLabel(for number: Int) -> String {
        let monitorNumber: Int
        if case .point(let selectedMonitor) = step {
            monitorNumber = selectedMonitor
        } else if case .nudge(let selectedMonitor) = step {
            monitorNumber = selectedMonitor
        } else {
            monitorNumber = 1
        }

        if monitorNumber == 2 {
            return [1: "U", 2: "I", 3: "O", 4: "J", 5: "K", 6: "L", 7: "N", 8: "M", 9: ","][number] ?? ""
        }

        return [1: "Q", 2: "W", 3: "E", 4: "A", 5: "S", 6: "D", 7: "Z", 8: "X", 9: "C"][number] ?? ""
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
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovering ? 0.95 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
