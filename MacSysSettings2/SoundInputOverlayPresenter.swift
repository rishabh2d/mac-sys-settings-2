//
//  SoundInputOverlayPresenter.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import SwiftUI

@MainActor
final class SoundInputOverlayPresenter {
    private let panelSize = NSSize(width: 430, height: 340)
    private var panel: SoundInputPanel?

    func show(connectedDevice: AudioInputDevice) {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(
            rootView: SoundInputOverlayView(
                connectedDevice: connectedDevice,
                onClose: { [weak self] in
                    self?.hide()
                }
            )
        )
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

    private func makePanelIfNeeded() -> SoundInputPanel {
        if let panel {
            return panel
        }

        let panel = SoundInputPanel(
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

private final class SoundInputPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct SoundInputOverlayView: View {
    let connectedDevice: AudioInputDevice
    let onClose: () -> Void

    @State private var expanded = false
    @State private var devices = AudioInputStore.inputDevices()
    @State private var defaultDevice = AudioInputStore.defaultInputDevice()
    @State private var statusText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectedDevice.name)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Bluetooth audio connected")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
            }

            Button {
                expanded.toggle()
                refreshDevices()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound input")
                            .font(.system(size: 15, weight: .semibold))
                        Text(defaultDevice?.name ?? "No input selected")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            if expanded {
                VStack(spacing: 0) {
                    ForEach(devices) { device in
                        Button {
                            setDefault(device)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .lineLimit(1)
                                    Text(device.transport.label)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.58))
                                }

                                Spacer()

                                if device.id == defaultDevice?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 9)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)

                        if device.id != devices.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.18)))
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(statusText == "Switched" ? .green : .red)
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.34), radius: 28, y: 16)
        .onAppear {
            refreshDevices()
        }
    }

    private func refreshDevices() {
        devices = AudioInputStore.inputDevices()
        defaultDevice = AudioInputStore.defaultInputDevice()
    }

    private func setDefault(_ device: AudioInputDevice) {
        if AudioInputStore.setDefaultInputDevice(device) {
            statusText = "Switched"
            refreshDevices()
        } else {
            statusText = "Could not switch"
        }
    }
}
