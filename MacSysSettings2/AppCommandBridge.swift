//
//  AppCommandBridge.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import AppKit
import SwiftUI

@MainActor
enum AppCommandBridge {
    static var openMainWindow: (() -> Void)?

    static func showMainWindow() {
        CompactPanelController.shared.hideImmediately()
        openMainWindow?()

        DispatchQueue.main.async {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            for window in NSApp.windows where window.canBecomeMain || window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

private struct AppCommandBridgeRegistrar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                AppCommandBridge.openMainWindow = {
                    openWindow(id: "main")
                }
            }
    }
}

extension View {
    func registersAppCommands() -> some View {
        background(AppCommandBridgeRegistrar())
    }
}
