//
//  AudioTabChoicePresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/25/26.
//

import AppKit
import Carbon
import SwiftUI

struct AudioTabChoice: Identifiable, Equatable {
    let id: Int
    let number: Int
    let title: String
    let browserName: String
    let windowTitle: String
}

@MainActor
final class AudioTabChoicePresenter {
    private let panelWidth: CGFloat = 620
    private var panel: AudioTabChoicePanel?

    func show(
        choices: [AudioTabChoice],
        onSelect: @escaping (AudioTabChoice) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let visibleChoices = Array(choices.prefix(5))
        guard !visibleChoices.isEmpty else {
            onCancel()
            return
        }

        let panel = makePanelIfNeeded()
        let panelSize = panelSize(for: visibleChoices.count)
        panel.contentView = NSHostingView(
            rootView: AudioTabChoiceView(
                choices: visibleChoices,
                panelSize: panelSize,
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
            if event.keyCode == UInt16(kVK_Escape) {
                self?.hide()
                onCancel()
                return true
            }

            guard let characters = event.charactersIgnoringModifiers,
                  let number = Int(characters),
                  let choice = visibleChoices.first(where: { $0.number == number }) else {
                return false
            }

            self?.hide()
            onSelect(choice)
            return true
        }

        center(panel: panel, size: panelSize)
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

    private func makePanelIfNeeded() -> AudioTabChoicePanel {
        if let panel {
            return panel
        }

        let panel = AudioTabChoicePanel(
            contentRect: NSRect(origin: .zero, size: panelSize(for: 2)),
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

    private func panelSize(for choiceCount: Int) -> NSSize {
        let rows = CGFloat((min(max(choiceCount, 1), 5) + 1) / 2)
        let height = 98 + rows * 132 + max(0, rows - 1) * 12
        return NSSize(width: panelWidth, height: height)
    }

    private func center(panel: NSPanel, size: NSSize) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }

        panel.setFrame(
            NSRect(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }
}

private final class AudioTabChoicePanel: NSPanel {
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

private struct AudioTabChoiceView: View {
    let choices: [AudioTabChoice]
    let panelSize: NSSize
    let onSelect: (AudioTabChoice) -> Void
    let onCancel: () -> Void

    private var columns: [GridItem] {
        let count = min(max(choices.count, 1), 2)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Audio Tab")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Choose the tab playing sound")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                }

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.86))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(choices) { choice in
                    Button {
                        onSelect(choice)
                    } label: {
                        AudioTabChoiceRow(choice: choice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(width: panelSize.width, height: panelSize.height)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.94))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AudioTabChoiceRow: View {
    let choice: AudioTabChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(choice.title)
                .font(.system(size: 21, weight: .bold))
                .lineLimit(3)
                .truncationMode(.tail)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                Text(choice.browserName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("Press \(choice.number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(red: 0.02, green: 0.16, blue: 0.42).opacity(0.95))
                    )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
