//
//  MuteMediaCoordinator.swift
//  MacSysSettings2
//
//  Created by Codex on 07/04/26.
//

import Combine
import Foundation

@MainActor
final class MuteMediaCoordinator: ObservableObject {
    @Published var isMuteAutomationEnabled: Bool {
        didSet {
            guard isMuteAutomationEnabled != oldValue else { return }
            UserDefaults.standard.set(isMuteAutomationEnabled, forKey: Self.isMuteAutomationEnabledKey)
            applyEnabledState()
        }
    }

    private let muteMonitor = MuteKeyMonitor()
    private let mediaController = SystemMediaController()
    private let hudPresenter = CenteredHUDPresenter()
    private let debounceIntervalNanoseconds: UInt64 = 180_000_000
    private static let isMuteAutomationEnabledKey = "isMuteAutomationEnabled"

    private var pausedByApp = false
    private var pausedTarget: SystemMediaController.PlaybackTarget?
    private var hasStarted = false
    private var latestMutedState: Bool?
    private var debounceTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?

    init() {
        if UserDefaults.standard.object(forKey: Self.isMuteAutomationEnabledKey) == nil {
            self.isMuteAutomationEnabled = true
        } else {
            self.isMuteAutomationEnabled = UserDefaults.standard.bool(forKey: Self.isMuteAutomationEnabledKey)
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        applyEnabledState()
    }

    private func applyEnabledState() {
        guard hasStarted else { return }

        if isMuteAutomationEnabled {
            let initialMutedState = SystemAudioState.currentOutputMuted()
            muteMonitor.start(initialMutedState: initialMutedState) { [weak self] isMuted in
                self?.handleMuteStateUpdate(isMuted)
            }
            print("MacSysSettings2: mute automation enabled")
        } else {
            debounceTask?.cancel()
            actionTask?.cancel()
            latestMutedState = nil
            pausedByApp = false
            pausedTarget = nil
            muteMonitor.stop()
            print("MacSysSettings2: mute automation disabled")
        }
    }

    private func handleMuteStateUpdate(_ isMuted: Bool) {
        latestMutedState = isMuted
        debounceTask?.cancel()

        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceIntervalNanoseconds)
            guard !Task.isCancelled else { return }
            guard let latestMutedState else { return }

            print("MacSysSettings2: mute state settled. muted=\(latestMutedState)")
            actionTask?.cancel()
            actionTask = Task { @MainActor [weak self] in
                guard let self else { return }

                if latestMutedState {
                    await handleMuteEnabled()
                } else {
                    await handleMuteDisabled()
                }
            }
        }
    }

    private func handleMuteEnabled() async {
        guard let target = await mediaController.targetToPauseOnMute() else {
            print("MacSysSettings2: mute pressed but no supported active media session was found")
            return
        }

        if await mediaController.pauseIfPlaying(target: target) {
            pausedByApp = true
            pausedTarget = target
            hudPresenter.show(.paused)
        }
    }

    private func handleMuteDisabled() async {
        guard pausedByApp else { return }
        guard let pausedTarget else { return }

        if await mediaController.resumeIfNeeded(target: pausedTarget) {
            pausedByApp = false
            self.pausedTarget = nil
            hudPresenter.show(.played)
        }
    }
}
