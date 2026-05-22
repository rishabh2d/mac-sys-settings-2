//
//  BluetoothAudioInputController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import CoreAudio
import Combine
import Foundation

@MainActor
final class BluetoothAudioInputController: ObservableObject {
    @Published private(set) var lastStatus = "Ready"

    private let presenter = SoundInputOverlayPresenter()
    private var knownDeviceIDs = Set<AudioObjectID>()
    private var pollingTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    func start() {
        knownDeviceIDs = Set(AudioInputStore.inputDevices().map(\.id))
        observeSettingChanges()
        restartPolling()
    }

    deinit {
        pollingTask?.cancel()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observeSettingChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: BluetoothAudioInputPromptStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartPolling()
            }
        }
    }

    private func restartPolling() {
        pollingTask?.cancel()

        guard BluetoothAudioInputPromptStore.isEnabled else {
            presenter.hide()
            lastStatus = "Off"
            return
        }

        lastStatus = "Watching Bluetooth audio"
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.scanForNewAudioInputs()
            }
        }
    }

    private func scanForNewAudioInputs() {
        guard BluetoothAudioInputPromptStore.isEnabled else { return }

        let devices = AudioInputStore.inputDevices()
        let latestIDs = Set(devices.map(\.id))
        let newIDs = latestIDs.subtracting(knownDeviceIDs)
        knownDeviceIDs = latestIDs

        guard let newBluetoothDevice = devices.first(where: { newIDs.contains($0.id) && $0.isBluetoothAudio }) else {
            return
        }

        lastStatus = "Detected \(newBluetoothDevice.name)"
        presenter.show(connectedDevice: newBluetoothDevice)
    }
}
