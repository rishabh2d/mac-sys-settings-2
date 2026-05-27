//
//  FinderSortChooserPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import Carbon
import SwiftUI

enum FinderSortChoice: String, CaseIterable, Identifiable {
    case dateCreated
    case dateModified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateCreated: return "Date Created"
        case .dateModified: return "Date Modified"
        }
    }

    var keyHint: String {
        switch self {
        case .dateCreated: return "C"
        case .dateModified: return "M"
        }
    }

    var symbolName: String {
        switch self {
        case .dateCreated: return "calendar.badge.plus"
        case .dateModified: return "calendar.badge.clock"
        }
    }
}

@MainActor
final class FinderSortChooserPresenter {
    private let panelSize = NSSize(width: 440, height: 236)
    private var panel: FinderSortChooserPanel?

    func show(onSelect: @escaping (FinderSortChoice) -> Void) {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: FinderSortChooserView { [weak self] choice in
                self?.hide()
                onSelect(choice)
            } onCancel: { [weak self] in
                self?.hide()
            }
        )
        panel.onKeyDown = { [weak self] event in
            guard let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }
            if characters == "c" {
                self?.hide()
                onSelect(.dateCreated)
                return true
            }
            if characters == "m" {
                self?.hide()
                onSelect(.dateModified)
                return true
            }
            if event.keyCode == UInt16(kVK_Escape) {
                self?.hide()
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

    private func makePanelIfNeeded() -> FinderSortChooserPanel {
        if let panel {
            return panel
        }

        let panel = FinderSortChooserPanel(
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
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

private final class FinderSortChooserPanel: NSPanel {
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

private struct FinderSortChooserView: View {
    let onSelect: (FinderSortChoice) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sort Finder Folder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Apply sorting to the front Finder window.")
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

            HStack(spacing: 12) {
                ForEach(FinderSortChoice.allCases) { choice in
                    Button {
                        onSelect(choice)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: choice.symbolName)
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Text(choice.keyHint)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.76))
                                    .frame(width: 26, height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.14))
                                    )
                            }

                            Text(choice.title)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.13))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 236)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
