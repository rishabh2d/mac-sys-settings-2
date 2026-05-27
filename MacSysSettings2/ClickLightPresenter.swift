//
//  ClickLightPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/25/26.
//

import AppKit
import SwiftUI

@MainActor
final class ClickLightPresenter {
    private var panels: [ClickLightPanel] = []
    private var cursorPanel: ClickLightPanel?

    func show(kind: ClickLightKind, at point: CGPoint) {
        let size = CGFloat(ClickLightStore.size)
        let duration = ClickLightStore.duration
        let intensity = ClickLightStore.intensity
        let panelSize = CGSize(width: size * 1.7, height: size * 1.7)
        let origin = CGPoint(x: point.x - panelSize.width / 2, y: point.y - panelSize.height / 2)

        let panel = ClickLightPanel(
            contentRect: CGRect(origin: origin, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(
            rootView: ClickLightPulseView(
                kind: kind,
                size: size,
                duration: duration,
                intensity: intensity
            )
        )

        panels.append(panel)
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.18) { [weak self, weak panel] in
            guard let panel else { return }
            panel.close()
            self?.panels.removeAll { $0 === panel }
        }
    }

    func updateCursorHighlight(at point: CGPoint) {
        let size = CGFloat(ClickLightStore.size)
        let panelSize = CGSize(width: size * 1.18, height: size * 1.18)
        let frame = CGRect(
            x: point.x - panelSize.width / 2,
            y: point.y - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )

        if let cursorPanel {
            cursorPanel.setFrame(frame, display: true)
            cursorPanel.orderFrontRegardless()
            return
        }

        let panel = ClickLightPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = ClickLightCursorNSView(size: size, intensity: ClickLightStore.intensity)
        cursorPanel = panel
        panel.orderFrontRegardless()
    }

    func hideCursorHighlight() {
        cursorPanel?.close()
        cursorPanel = nil
    }
}

enum ClickLightKind {
    case press
    case release
    case rightClick
    case drag

    var color: Color {
        switch self {
        case .press:
            return Color(red: 0.20, green: 0.62, blue: 1.0)
        case .release:
            return Color(red: 0.28, green: 0.84, blue: 0.56)
        case .rightClick:
            return Color(red: 1.0, green: 0.52, blue: 0.24)
        case .drag:
            return Color(red: 0.72, green: 0.50, blue: 1.0)
        }
    }
}

private final class ClickLightPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct ClickLightPulseView: View {
    let kind: ClickLightKind
    let size: CGFloat
    let duration: Double
    let intensity: Double

    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(kind.color.opacity(0.88 * intensity), lineWidth: max(3, size * 0.075))
                .frame(width: size, height: size)
                .scaleEffect(expanded ? 1.48 : 0.62)
                .opacity(expanded ? 0 : 1)

            Circle()
                .fill(kind.color.opacity(0.18 * intensity))
                .frame(width: size * 0.58, height: size * 0.58)
                .scaleEffect(expanded ? 1.05 : 0.48)
                .opacity(expanded ? 0 : 1)

            if kind == .drag {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(kind.color.opacity(0.72 * intensity))
                    .frame(width: size * 0.72, height: max(3, size * 0.08))
                    .rotationEffect(.degrees(26))
                    .opacity(expanded ? 0 : 0.95)
            }
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .onAppear {
            withAnimation(.easeOut(duration: duration)) {
                expanded = true
            }
        }
    }
}

private final class ClickLightCursorNSView: NSView {
    private let size: CGFloat
    private let intensity: Double

    init(size: CGFloat, intensity: Double) {
        self.size = size
        self.intensity = intensity
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: size * 1.18, height: size * 1.18)))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let inset = max(4, size * 0.08)
        let outerRect = bounds.insetBy(dx: inset, dy: inset)
        let innerRect = bounds.insetBy(dx: inset + max(5, size * 0.10), dy: inset + max(5, size * 0.10))

        NSColor.black.withAlphaComponent(0.34 * intensity).setStroke()
        let shadowPath = NSBezierPath(ovalIn: outerRect.offsetBy(dx: 0, dy: -1))
        shadowPath.lineWidth = max(3, size * 0.06)
        shadowPath.stroke()

        NSColor.white.withAlphaComponent(0.94 * intensity).setStroke()
        let outerPath = NSBezierPath(ovalIn: outerRect)
        outerPath.lineWidth = max(2, size * 0.045)
        outerPath.stroke()

        NSColor(calibratedRed: 0.20, green: 0.62, blue: 1.0, alpha: 0.72 * intensity).setStroke()
        let innerPath = NSBezierPath(ovalIn: innerRect)
        innerPath.lineWidth = max(2, size * 0.035)
        innerPath.stroke()
    }
}
