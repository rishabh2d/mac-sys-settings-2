//
//  MonitorMoveOverlayPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import SwiftUI

@MainActor
final class MonitorMoveOverlayPresenter {
    private var panels: [NSPanel] = []
    private var dismissTask: Task<Void, Never>?

    func show(
        screens: [NSScreen],
        sourceScreen: NSScreen,
        onSelect: @escaping (NSScreen) -> Void
    ) {
        hide()

        guard let sourceIndex = screens.firstIndex(of: sourceScreen) else { return }

        for (index, screen) in screens.enumerated() {
            let panel = makePanel(for: screen)
            let screenNumber = displayNumber(index: index, sourceIndex: sourceIndex)

            if screen == sourceScreen {
                panel.ignoresMouseEvents = false
                panel.contentView = NSHostingView(
                    rootView: MonitorChoiceView(
                        screens: screens,
                        sourceScreen: sourceScreen,
                        displayNumber: { [weak self] index in
                            self?.displayNumber(index: index, sourceIndex: sourceIndex) ?? index + 1
                        },
                        onSelect: { target in
                            onSelect(target)
                        }
                    )
                )
            } else {
                panel.ignoresMouseEvents = true
                panel.contentView = NSHostingView(rootView: ScreenLabelView(number: screenNumber))
            }

            panels.append(panel)
            panel.orderFrontRegardless()
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, !Task.isCancelled else { return }
            hide()
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.setFrame(screen.frame, display: true)
        return panel
    }

    private func displayNumber(index: Int, sourceIndex: Int) -> Int {
        if index == sourceIndex {
            return 1
        }

        return index < sourceIndex ? index + 2 : index + 1
    }
}

private struct MonitorChoiceView: View {
    let screens: [NSScreen]
    let sourceScreen: NSScreen
    let displayNumber: (Int) -> Int
    let onSelect: (NSScreen) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.14)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Move this monitor to")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        Button {
                            guard screen != sourceScreen else { return }
                            onSelect(screen)
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(displayNumber(index))")
                                    .font(.system(size: 34, weight: .bold))
                                Text(screen == sourceScreen ? "Current" : "Screen")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(screen == sourceScreen ? .white.opacity(0.38) : .white)
                            .frame(width: 90, height: 78)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(screen == sourceScreen ? Color.white.opacity(0.08) : Color.white.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(screen == sourceScreen ? 0.12 : 0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(screen == sourceScreen)
                    }
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
        }
    }
}

private struct ScreenLabelView: View {
    let number: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            Text("Screen \(number)")
                .font(.system(size: 96, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
        }
    }
}
