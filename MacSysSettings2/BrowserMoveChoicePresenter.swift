//
//  BrowserMoveChoicePresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon
import SwiftUI

@MainActor
final class BrowserMoveChoicePresenter {
    enum Choice {
        case tab
        case window
    }

    private let panelSize = NSSize(width: 330, height: 190)
    private var panel: BrowserMoveChoicePanel?
    private var keyMonitor: Any?
    private var onChoice: ((Choice) -> Void)?

    func show(appName: String, onChoice: @escaping (Choice) -> Void) {
        hide()
        self.onChoice = onChoice

        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: BrowserMoveChoiceView(appName: appName) { [weak self] choice in
                self?.choose(choice)
            } onCancel: { [weak self] in
                self?.hide()
            }
        )
        center(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        installKeyMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        onChoice = nil

        guard let panel else { return }
        panel.orderOut(nil)
    }

    private func choose(_ choice: Choice) {
        let handler = onChoice
        hide()
        handler?(choice)
    }

    private func makePanelIfNeeded() -> BrowserMoveChoicePanel {
        if let panel {
            return panel
        }

        let panel = BrowserMoveChoicePanel(
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

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "t" {
                Task { @MainActor in self?.choose(.tab) }
                return nil
            }
            if key == "w" {
                Task { @MainActor in self?.choose(.window) }
                return nil
            }
            if event.keyCode == UInt16(kVK_Escape) {
                Task { @MainActor in self?.hide() }
                return nil
            }
            return event
        }
    }
}

private final class BrowserMoveChoicePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct BrowserMoveChoiceView: View {
    let appName: String
    let onChoice: (BrowserMoveChoicePresenter.Choice) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Move tab or window?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
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

            HStack(spacing: 12) {
                choiceButton(letter: "T", title: "Tab", subtitle: appName) {
                    onChoice(.tab)
                }
                choiceButton(letter: "W", title: "Window", subtitle: "Whole window") {
                    onChoice(.window)
                }
            }
        }
        .padding(18)
        .frame(width: 330, height: 190)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func choiceButton(letter: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Text(letter)
                    .font(.system(size: 34, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
