//
//  MacSysSettings2App.swift
//  MacSysSettings2
//
//  Created by Rishabh on 07/04/26.
//

import SwiftUI

@main
struct MacSysSettings2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = MuteMediaCoordinator()
    @StateObject private var screenShortcutController = ScreenShortcutController.shared
    @StateObject private var windowSwitcherController = WindowSwitcherController()
    @StateObject private var downloadsWatcherController = DownloadsWatcherController()
    @StateObject private var screenshotClipboardController = ScreenshotClipboardController()
    @StateObject private var hoverFocusController = HoverFocusController()
    @StateObject private var finderSortShortcutController = FinderSortShortcutController()
    @StateObject private var autoScrollController = AutoScrollController()
    @StateObject private var fullscreenEscapeController = FullscreenEscapeController()
    @StateObject private var bluetoothAudioInputController = BluetoothAudioInputController()
    @StateObject private var cursorJumpController = CursorJumpController.shared
    @StateObject private var fileShelfController = FileShelfController.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(
                coordinator: coordinator,
                downloadsWatcherController: downloadsWatcherController,
                screenshotClipboardController: screenshotClipboardController
            )
                .registersAppCommands()
                .task {
                    LoginItemStore.enableByDefaultIfNeeded()
                    screenShortcutController.start()
                    windowSwitcherController.start()
                    downloadsWatcherController.start()
                    screenshotClipboardController.start()
                    hoverFocusController.start()
                    finderSortShortcutController.start()
                    autoScrollController.start()
                    fullscreenEscapeController.start()
                    bluetoothAudioInputController.start()
                    cursorJumpController.start()
                    fileShelfController.start()
                }
        }
    }
}
