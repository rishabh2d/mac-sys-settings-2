//
//  BluetoothSleepController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Combine
import Foundation
import IOBluetooth

@_silgen_name("IOBluetoothPreferenceSetControllerPowerState")
private func IOBluetoothPreferenceSetControllerPowerState(_ state: Int32) -> Int32

@MainActor
final class BluetoothSleepController: ObservableObject {
    static let shared = BluetoothSleepController()

    @Published private(set) var lastStatus = BluetoothSleepStore.lastStatus

    private var observers: [NSObjectProtocol] = []
    private var isStarted = false

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleWillSleep()
                }
            }
        )

        observers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleDidWake()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: BluetoothSleepStore.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.lastStatus = BluetoothSleepStore.lastStatus
                }
            }
        )

        updateStatus(BluetoothSleepStore.isEnabled ? "Ready" : "Off")
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func handleWillSleep() {
        guard BluetoothSleepStore.isEnabled else {
            updateStatus("Off")
            return
        }

        if BluetoothSleepStore.onlyOnBattery && !PowerSourceStatus.isOnBattery {
            BluetoothSleepStore.setTurnedOffByApp(false)
            updateStatus("Plugged in, skipped")
            return
        }

        guard BluetoothPower.isOn else {
            BluetoothSleepStore.setTurnedOffByApp(false)
            updateStatus("Bluetooth already off")
            return
        }

        if BluetoothPower.setOn(false) {
            BluetoothSleepStore.setTurnedOffByApp(true)
            updateStatus("Turned off for sleep")
        } else {
            BluetoothSleepStore.setTurnedOffByApp(false)
            updateStatus("Could not turn off")
        }
    }

    private func handleDidWake() {
        guard BluetoothSleepStore.isEnabled else {
            updateStatus("Off")
            return
        }

        guard BluetoothSleepStore.turnedOffByApp else {
            updateStatus("Nothing to restore")
            return
        }

        if BluetoothPower.setOn(true) {
            BluetoothSleepStore.setTurnedOffByApp(false)
            updateStatus("Restored on wake")
        } else {
            updateStatus("Could not restore")
        }
    }

    private func updateStatus(_ status: String) {
        lastStatus = status
        BluetoothSleepStore.setLastStatus(status)
    }
}

private nonisolated enum BluetoothPower {
    static var isOn: Bool {
        IOBluetoothHostController.default().powerState == kBluetoothHCIPowerStateON
    }

    static func setOn(_ isOn: Bool) -> Bool {
        let target = isOn ? kBluetoothHCIPowerStateON : kBluetoothHCIPowerStateOFF
        let result = IOBluetoothPreferenceSetControllerPowerState(Int32(target.rawValue))

        if result != 0 {
            return false
        }

        Thread.sleep(forTimeInterval: 0.25)
        return IOBluetoothHostController.default().powerState == target
    }
}

private nonisolated enum PowerSourceStatus {
    static var isOnBattery: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.localizedCaseInsensitiveContains("Battery Power")
    }
}
