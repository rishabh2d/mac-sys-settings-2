//
//  MicNetworkWarningController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/22/26.
//

import AppKit
import Combine
import CoreWLAN
import Foundation
import SystemConfiguration

@MainActor
final class MicNetworkWarningController: ObservableObject {
    static let shared = MicNetworkWarningController()

    @Published private(set) var lastStatus = "Ready"

    private let presenter = MicNetworkWarningPresenter()
    private var pollingTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var wasMicActive = false
    private var hasWarnedForCurrentMicSession = false
    private var warnedFrontmostBundleIDs = Set<String>()

    func start() {
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
            forName: MicNetworkWarningStore.didChangeNotification,
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
        wasMicActive = false
        hasWarnedForCurrentMicSession = false
        warnedFrontmostBundleIDs.removeAll()

        guard MicNetworkWarningStore.isEnabled else {
            presenter.hide()
            lastStatus = "Off"
            return
        }

        lastStatus = "Watching mic"
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.scan()
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }

    private func scan() {
        guard MicNetworkWarningStore.isEnabled else { return }

        let activeNames = AudioInputStore.activeInputDeviceNames()
        let micActive = !activeNames.isEmpty
        let wiFiState = WiFiState.current()

        if micActive {
            lastStatus = wiFiState.isAvailable ? "Mic active, Wi-Fi ready" : "Mic active, Wi-Fi off"
        } else {
            lastStatus = wiFiState.label
            hasWarnedForCurrentMicSession = false
            warnedFrontmostBundleIDs.removeAll()
        }

        defer {
            wasMicActive = micActive
        }

        guard micActive, !wiFiState.isAvailable else { return }
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let shouldWarnForApp = frontmostBundleID == "com.openai.codex" || frontmostBundleID.localizedCaseInsensitiveContains("wispr")
        guard shouldWarnForApp else { return }
        guard !hasWarnedForCurrentMicSession || !warnedFrontmostBundleIDs.contains(frontmostBundleID) else { return }

        hasWarnedForCurrentMicSession = true
        if !frontmostBundleID.isEmpty {
            warnedFrontmostBundleIDs.insert(frontmostBundleID)
        }
        presenter.show(detail: activeNames.first ?? "Microphone active")
    }
}

private struct WiFiState {
    let isAvailable: Bool
    let label: String
    let title: String
    let detail: String

    static func current() -> WiFiState {
        let internetIsReachable = isInternetReachable()

        guard let interface = CWWiFiClient.shared().interface() else {
            if internetIsReachable {
                return WiFiState(
                    isAvailable: true,
                    label: "Network ready",
                    title: "Network ready",
                    detail: "Internet is reachable"
                )
            }
            return WiFiState(
                isAvailable: false,
                label: "No Wi-Fi",
                title: "Wi-Fi unavailable",
                detail: "Wi-Fi is unavailable"
            )
        }

        if !interface.powerOn() {
            if internetIsReachable {
                return WiFiState(
                    isAvailable: true,
                    label: "Network ready",
                    title: "Network ready",
                    detail: "Internet is reachable"
                )
            }
            return WiFiState(
                isAvailable: false,
                label: "Wi-Fi off",
                title: "Wi-Fi is off",
                detail: "Wi-Fi is turned off"
            )
        }

        if interface.ssid() == nil {
            if internetIsReachable {
                return WiFiState(
                    isAvailable: true,
                    label: "Network ready",
                    title: "Network ready",
                    detail: "Internet is reachable"
                )
            }
            return WiFiState(
                isAvailable: false,
                label: "Wi-Fi disconnected",
                title: "Wi-Fi disconnected",
                detail: "Wi-Fi is not connected"
            )
        }

        return WiFiState(
            isAvailable: true,
            label: "Wi-Fi ready",
            title: "Wi-Fi ready",
            detail: "Wi-Fi is connected"
        )
    }

    private static func isInternetReachable() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com") else {
            return false
        }

        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }

        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
}
