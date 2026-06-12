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
    private static let mainWindowWidth: CGFloat = 720

    static func showMainWindow() {
        AppSurfaceStore.setLastSurface(.main)
        CompactPanelController.shared.hideImmediately()

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let window = existingMainWindow() {
            positionMainWindow(window)
            window.makeKeyAndOrderFront(nil)
            return
        }

        openMainWindow?()

        DispatchQueue.main.async {
            if let window = existingMainWindow() {
                positionMainWindow(window)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private static func existingMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.title == "Mac Sys Settings 2" && !(window is NSPanel)
        } ?? NSApp.windows.first { window in
            window.canBecomeMain && !(window is NSPanel)
        }
    }

    private static func positionMainWindow(_ window: NSWindow) {
        guard let screen = screenUnderMouse() ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let width = min(mainWindowWidth, visibleFrame.width)
        let frame = NSRect(
            x: visibleFrame.maxX - width,
            y: visibleFrame.minY,
            width: width,
            height: visibleFrame.height
        )

        window.minSize = NSSize(width: min(width, mainWindowWidth), height: min(visibleFrame.height, 720))
        window.setFrame(frame, display: true, animate: false)
    }

    private static func screenUnderMouse() -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
    }
}

enum AppSurface: String {
    case compact
    case main
}

enum AppSurfaceStore {
    private static let lastSurfaceKey = "app.lastOpenedSurface"

    static var lastSurface: AppSurface {
        AppSurface(rawValue: UserDefaults.standard.string(forKey: lastSurfaceKey) ?? "") ?? .compact
    }

    static func setLastSurface(_ surface: AppSurface) {
        UserDefaults.standard.set(surface.rawValue, forKey: lastSurfaceKey)
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
