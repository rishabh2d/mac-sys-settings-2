//
//  AutoScrollOverlayPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import Carbon
import SwiftUI

enum AutoScrollDirection: String, CaseIterable {
    case up
    case down

    var title: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        }
    }

    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    var sign: Int32 {
        switch self {
        case .up: return 1
        case .down: return -1
        }
    }
}

enum AutoScrollSpeed: String, CaseIterable {
    case slow
    case medium
    case fast

    var title: String {
        switch self {
        case .slow: return "Slow"
        case .medium: return "Medium"
        case .fast: return "Fast"
        }
    }

    var wheelDelta: Int32 {
        switch self {
        case .slow: return 3
        case .medium: return 7
        case .fast: return 13
        }
    }
}

struct AutoScrollChoice: Identifiable {
    let direction: AutoScrollDirection
    let speed: AutoScrollSpeed

    var id: String { "\(direction.rawValue)-\(speed.rawValue)" }
    var title: String { "\(direction.title) \(speed.title)" }
}

@MainActor
final class AutoScrollOverlayPresenter {
    private let panelSize = NSSize(width: 470, height: 330)
    private var panel: AutoScrollPanel?

    func show(onSelect: @escaping (AutoScrollChoice) -> Void, onCancel: @escaping () -> Void) {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: AutoScrollOverlayView(
                onSelect: { [weak self] choice in
                    self?.hide()
                    onSelect(choice)
                },
                onCancel: { [weak self] in
                    self?.hide()
                    onCancel()
                }
            )
        )

        panel.onKeyDown = { [weak self] event in
            guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }

            let mapping: [String: AutoScrollChoice] = [
                "1": AutoScrollChoice(direction: .up, speed: .slow),
                "2": AutoScrollChoice(direction: .up, speed: .medium),
                "3": AutoScrollChoice(direction: .up, speed: .fast),
                "4": AutoScrollChoice(direction: .down, speed: .slow),
                "5": AutoScrollChoice(direction: .down, speed: .medium),
                "6": AutoScrollChoice(direction: .down, speed: .fast)
            ]

            if let choice = mapping[characters] {
                self?.hide()
                onSelect(choice)
                return true
            }

            if event.keyCode == UInt16(kVK_Escape) {
                self?.hide()
                onCancel()
                return true
            }

            return false
        }

        center(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanelIfNeeded() -> AutoScrollPanel {
        if let panel {
            return panel
        }

        let panel = AutoScrollPanel(
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
}

private final class AutoScrollPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

private struct AutoScrollOverlayView: View {
    let onSelect: (AutoScrollChoice) -> Void
    let onCancel: () -> Void

    private let choices: [(String, AutoScrollDirection, [AutoScrollSpeed])] = [
        ("Scroll up", .up, [.slow, .medium, .fast]),
        ("Scroll down", .down, [.slow, .medium, .fast])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Autoscroll")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Choose direction and speed. Press Control-Option-Command-A again to stop.")
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

            VStack(spacing: 12) {
                ForEach(Array(choices.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 10) {
                        Label(row.0, systemImage: row.1.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(width: 104, alignment: .leading)

                        ForEach(Array(row.2.enumerated()), id: \.element.rawValue) { speedIndex, speed in
                            let number = rowIndex * 3 + speedIndex + 1
                            Button {
                                onSelect(AutoScrollChoice(direction: row.1, speed: speed))
                            } label: {
                                VStack(spacing: 7) {
                                    Text("\(number)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.72))
                                        .frame(width: 24, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color.white.opacity(0.14))
                                        )

                                    Text(speed.title)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 74)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.13))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button(action: onCancel) {
                Text("Stop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 470, height: 330)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
