//
//  SpaceMenuCommandController.swift
//  MacSysSettings2
//
//  Created by Codex on 06/12/26.
//

import AppKit

@MainActor
final class SpaceMenuCommandController {
    static let shared = SpaceMenuCommandController()

    private init() {}

    func showMissionControl() {
        runOpenBundle("com.apple.exposelauncher")
    }

    private func runOpenBundle(_ bundleIdentifier: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleIdentifier]
        try? process.run()
    }
}
