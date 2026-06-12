//
//  ChromeTabMergeChoicePresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/25/26.
//

import AppKit
import Carbon
import SwiftUI

struct ChromeTabMergeWindowChoice: Identifiable, Equatable {
    let id: Int
    let number: Int
    let title: String
    let domain: String
    let position: String
    let isAudible: Bool
}

@MainActor
final class ChromeTabMergeChoicePresenter {
    private let panelWidth: CGFloat = 560
    private var panel: ChromeTabMergeChoicePanel?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    func show(
        sourceTitle: String,
        sourceDomain: String,
        anchorScreenFrame: CGRect?,
        choices: [ChromeTabMergeWindowChoice],
        onSelect: @escaping (ChromeTabMergeWindowChoice) -> Void,
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
            rootView: ChromeTabMergeChoiceView(
                sourceTitle: sourceTitle,
                sourceDomain: sourceDomain,
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
            self?.handleKey(event, choices: visibleChoices, onSelect: onSelect, onCancel: onCancel) ?? false
        }
        installKeyMonitors(choices: visibleChoices, onSelect: onSelect, onCancel: onCancel)

        center(panel: panel, size: panelSize, anchorScreenFrame: anchorScreenFrame)
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
        removeKeyMonitors()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func installKeyMonitors(
        choices: [ChromeTabMergeWindowChoice],
        onSelect: @escaping (ChromeTabMergeWindowChoice) -> Void,
        onCancel: @escaping () -> Void
    ) {
        removeKeyMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKey(event, choices: choices, onSelect: onSelect, onCancel: onCancel) == true {
                return nil
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                _ = self?.handleKey(event, choices: choices, onSelect: onSelect, onCancel: onCancel)
            }
        }
    }

    private func removeKeyMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }

    private func handleKey(
        _ event: NSEvent,
        choices: [ChromeTabMergeWindowChoice],
        onSelect: @escaping (ChromeTabMergeWindowChoice) -> Void,
        onCancel: @escaping () -> Void
    ) -> Bool {
        if event.keyCode == UInt16(kVK_Escape) {
            hide()
            onCancel()
            return true
        }

        guard let characters = event.charactersIgnoringModifiers,
              let number = Int(characters),
              let choice = choices.first(where: { $0.number == number }) else {
            return false
        }

        hide()
        onSelect(choice)
        return true
    }

    private func makePanelIfNeeded() -> ChromeTabMergeChoicePanel {
        if let panel {
            return panel
        }

        let panel = ChromeTabMergeChoicePanel(
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
        let count = CGFloat(min(max(choiceCount, 1), 5))
        let height = 90 + count * 74 + max(0, count - 1) * 10
        return NSSize(width: panelWidth, height: height)
    }

    private func center(panel: NSPanel, size: NSSize, anchorScreenFrame: CGRect?) {
        let frame = anchorScreenFrame
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame

        guard let frame else { return }

        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }
}

private final class ChromeTabMergeChoicePanel: NSPanel {
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

private struct ChromeTabMergeChoiceView: View {
    let sourceTitle: String
    let sourceDomain: String
    let choices: [ChromeTabMergeWindowChoice]
    let panelSize: NSSize
    let onSelect: (ChromeTabMergeWindowChoice) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Merge Chrome Tab")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text(sourceSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.white.opacity(0.70))
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

            VStack(spacing: 10) {
                ForEach(choices) { choice in
                    choiceRow(choice)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: panelSize.width, height: panelSize.height)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.94))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var sourceSubtitle: String {
        let title = sourceTitle.isEmpty ? "active tab" : sourceTitle
        if sourceDomain.isEmpty {
            return "Choose destination window"
        }
        return "Choose where to put \(title)"
    }

    private func choiceRow(_ choice: ChromeTabMergeWindowChoice) -> some View {
        Button {
            onSelect(choice)
        } label: {
            ChromeTabMergeChoiceRow(choice: choice)
        }
        .buttonStyle(.plain)
    }
}

private struct ChromeTabMergeChoiceRow: View {
    let choice: ChromeTabMergeWindowChoice

    var body: some View {
        HStack(spacing: 12) {
            Text("\(choice.number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(red: 0.02, green: 0.16, blue: 0.42).opacity(0.95))
                )

            VStack(alignment: .leading, spacing: 4) {
                titleLine
                detailLine
            }

            Spacer(minLength: 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var titleLine: some View {
        Text(choice.title.isEmpty ? "Untitled tab" : choice.title)
            .font(.system(size: 15.5, weight: .bold))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailLine: some View {
        HStack(spacing: 7) {
            Text(choice.domain.isEmpty ? "Chrome window" : choice.domain)
            Text("-")
            Text(choice.position)
        }
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(.white.opacity(0.60))
        .lineLimit(1)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.12))
    }
}
