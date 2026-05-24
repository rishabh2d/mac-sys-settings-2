//
//  CursorLocatorPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import SwiftUI

@MainActor
final class CursorLocatorPresenter {
    static let shared = CursorLocatorPresenter()

    private var panel: CursorLocatorPanel?
    private var hideTask: Task<Void, Never>?

    private init() {}

    func show(at point: NSPoint = NSEvent.mouseLocation) {
        hideTask?.cancel()

        let panel = makePanelIfNeeded()
        let size = NSSize(width: 168, height: 168)
        panel.setFrame(
            NSRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        panel.contentView = NSHostingView(rootView: CursorLocatorRingView())
        panel.orderFrontRegardless()

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            self?.hide()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
    }

    private func makePanelIfNeeded() -> CursorLocatorPanel {
        if let panel {
            return panel
        }

        let panel = CursorLocatorPanel(
            contentRect: NSRect(x: 0, y: 0, width: 168, height: 168),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        self.panel = panel
        return panel
    }
}

private final class CursorLocatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct CursorLocatorRingView: View {
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(expanded ? 0 : 0.92), lineWidth: expanded ? 2 : 8)
                .frame(width: expanded ? 146 : 26, height: expanded ? 146 : 26)
                .shadow(color: Color(red: 0.12, green: 0.58, blue: 1).opacity(expanded ? 0 : 0.95), radius: 18)

            Circle()
                .stroke(Color(red: 0.20, green: 0.62, blue: 1).opacity(expanded ? 0 : 0.82), lineWidth: expanded ? 1 : 5)
                .frame(width: expanded ? 112 : 18, height: expanded ? 112 : 18)

            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: Color.black.opacity(0.35), radius: 4)
        }
        .frame(width: 168, height: 168)
        .allowsHitTesting(false)
        .onAppear {
            expanded = false
            withAnimation(.easeOut(duration: 0.9)) {
                expanded = true
            }
        }
    }
}
