//
//  SystemMediaController.swift
//  MacSysSettings2
//
//  Created by Codex on 07/04/26.
//

import AppKit
import Foundation
import IOKit.hidsystem

@MainActor
final class SystemMediaController {
    struct PlaybackTarget: Equatable {
        let bundleIdentifier: String
        let appName: String
    }

    private struct MediaState: Decodable {
        let bundleIdentifier: String?
        let isPlaying: Bool
    }

    private let supportedBundleIDs = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.spotify.client",
        "com.apple.QuickTimePlayerX"
    ]

    func targetToPauseOnMute() async -> PlaybackTarget? {
        guard let state = await currentMediaState() else {
            print("MacSysSettings2: media helper did not return a state")
            return nil
        }

        guard let bundleIdentifier = state.bundleIdentifier else {
            print("MacSysSettings2: no active media app was reported")
            return nil
        }

        guard supportedBundleIDs.contains(bundleIdentifier) else {
            print("MacSysSettings2: active media app \(bundleIdentifier) is not in supported scope")
            return nil
        }

        guard state.isPlaying else {
            print("MacSysSettings2: active media app \(bundleIdentifier) is already paused")
            return nil
        }

        let appName = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier })?
            .localizedName ?? bundleIdentifier

        print("MacSysSettings2: selected active media target \(bundleIdentifier)")
        return PlaybackTarget(bundleIdentifier: bundleIdentifier, appName: appName)
    }

    func pauseIfPlaying(target: PlaybackTarget) async -> Bool {
        guard let state = await currentMediaState() else {
            print("MacSysSettings2: could not confirm playing state for \(target.bundleIdentifier)")
            return false
        }

        guard state.bundleIdentifier == target.bundleIdentifier else {
            print("MacSysSettings2: active media app changed before pause")
            return false
        }

        guard state.isPlaying else {
            print("MacSysSettings2: \(target.bundleIdentifier) was already not playing")
            return false
        }

        let success = sendPlayPauseCommand()
        print("MacSysSettings2: play/pause sent to \(target.bundleIdentifier) success=\(success)")
        return success
    }

    func resumeIfNeeded(target: PlaybackTarget) async -> Bool {
        guard let state = await currentMediaState() else {
            print("MacSysSettings2: could not confirm resume state for \(target.bundleIdentifier)")
            return false
        }

        if let activeBundleID = state.bundleIdentifier, activeBundleID != target.bundleIdentifier {
            print("MacSysSettings2: resume skipped because active media app changed to \(activeBundleID)")
            return false
        }

        if state.isPlaying {
            print("MacSysSettings2: resume skipped because \(target.bundleIdentifier) is already playing")
            return false
        }

        let success = sendPlayPauseCommand()
        print("MacSysSettings2: resume play/pause sent to \(target.bundleIdentifier) success=\(success)")
        return success
    }

    private func currentMediaState() async -> MediaState? {
        let helperSource = """
        import Foundation
        import Dispatch
        import Darwin

        struct MediaState: Encodable {
            let bundleIdentifier: String?
            let isPlaying: Bool
        }

        typealias DisplayIDHandler = @convention(block) (Unmanaged<CFString>?) -> Void
        typealias GetDisplayID = @convention(c) (DispatchQueue, @escaping DisplayIDHandler) -> Void
        typealias IsPlayingHandler = @convention(block) (Bool) -> Void
        typealias GetIsPlaying = @convention(c) (DispatchQueue, @escaping IsPlayingHandler) -> Void

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            print("{\\"bundleIdentifier\\":null,\\"isPlaying\\":false}")
            exit(0)
        }

        guard
            let displayIDSymbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationDisplayID"),
            let isPlayingSymbol = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        else {
            print("{\\"bundleIdentifier\\":null,\\"isPlaying\\":false}")
            exit(0)
        }

        let getDisplayID = unsafeBitCast(displayIDSymbol, to: GetDisplayID.self)
        let getIsPlaying = unsafeBitCast(isPlayingSymbol, to: GetIsPlaying.self)

        final class Box {
            var bundleIdentifier: String?
            var isPlaying = false
            var didFinishDisplayID = false
            var didFinishIsPlaying = false
        }

        let box = Box()

        func finishIfNeeded() {
            guard box.didFinishDisplayID, box.didFinishIsPlaying else { return }
            let state = MediaState(bundleIdentifier: box.bundleIdentifier, isPlaying: box.isPlaying)
            let data = try! JSONEncoder().encode(state)
            print(String(decoding: data, as: UTF8.self))
            exit(0)
        }

        let displayCallback: DisplayIDHandler = { value in
            box.bundleIdentifier = value?.takeUnretainedValue() as String?
            box.didFinishDisplayID = true
            finishIfNeeded()
        }

        let isPlayingCallback: IsPlayingHandler = { value in
            box.isPlaying = value
            box.didFinishIsPlaying = true
            finishIfNeeded()
        }

        getDisplayID(.main, displayCallback)
        getIsPlaying(.main, isPlayingCallback)

        RunLoop.main.run(until: Date().addingTimeInterval(2))

        let fallbackState = MediaState(bundleIdentifier: box.bundleIdentifier, isPlaying: box.isPlaying)
        let fallbackData = try! JSONEncoder().encode(fallbackState)
        print(String(decoding: fallbackData, as: UTF8.self))
        """

        guard let output = await runSwiftHelper(helperSource) else {
            return nil
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(MediaState.self, from: data)
    }

    private func runSwiftHelper(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["swift", "-"]
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.standardInput = inputPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)
                let errorOutput = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if process.terminationStatus != 0 {
                    print("MacSysSettings2: media helper failed with status \(process.terminationStatus)")
                    if let output, !output.isEmpty {
                        print("MacSysSettings2: media helper output: \(output)")
                    }
                    if let errorOutput, !errorOutput.isEmpty {
                        print("MacSysSettings2: media helper error: \(errorOutput)")
                    }
                } else if let errorOutput, !errorOutput.isEmpty {
                    print("MacSysSettings2: media helper stderr: \(errorOutput)")
                }

                continuation.resume(returning: output)
            }

            do {
                try process.run()
                inputPipe.fileHandleForWriting.write(Data(source.utf8))
                try? inputPipe.fileHandleForWriting.close()
            } catch {
                print("MacSysSettings2: failed to run media helper: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    private func sendPlayPauseCommand() -> Bool {
        postMediaKey(NX_KEYTYPE_PLAY)
    }

    private func postMediaKey(_ keyType: Int32) -> Bool {
        postMediaKeyEvent(keyType, keyDown: true) && postMediaKeyEvent(keyType, keyDown: false)
    }

    private func postMediaKeyEvent(_ keyType: Int32, keyDown: Bool) -> Bool {
        let keyState = (keyDown ? 0xA : 0xB) << 8
        let flags = NSEvent.ModifierFlags(rawValue: UInt(keyState))
        let data1 = Int((keyType << 16) | Int32(keyState))

        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else {
            return false
        }

        guard let cgEvent = event.cgEvent else {
            return false
        }

        cgEvent.post(tap: .cghidEventTap)
        return true
    }
}
