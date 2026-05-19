//
//  MacSysSettings2App.swift
//  MacSysSettings2
//
//  Created by Rishabh on 07/04/26.
//

import SwiftUI

@main
struct MacSysSettings2App: App {
    @StateObject private var coordinator = MuteMediaCoordinator()
    @StateObject private var screenShortcutController = ScreenShortcutController()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
                .task {
                    LoginItemStore.enableByDefaultIfNeeded()
                    screenShortcutController.start()
                }
        }
    }
}
