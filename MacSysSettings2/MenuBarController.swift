//
//  MenuBarController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/19/26.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var batteryItem: NSStatusItem?
    private var batteryTimer: Timer?
    private var batteryPowerObserver: NSObjectProtocol?
    private var batteryStatsPanel: NSPanel?
    private var batteryStatsLocalMonitor: Any?
    private var batteryStatsGlobalMonitor: Any?
    private var menuModes: [WindowMode] = []
    private let modeChooserPresenter = ModeChooserPresenter()

    func start() {
        guard statusItem == nil else { return }

        NSApp.setActivationPolicy(.accessory)

        BatteryMenuStore.applyNativeBatteryVisibility()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "Mac Sys Settings 2")
            button.image?.isTemplate = true
            button.toolTip = "Mac Sys Settings 2"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusItem = item
        startBatteryItem()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            CompactPanelController.shared.show()
            return
        }

        showLayoutPresetChooser()
    }

    @objc private func openApp() {
        AppCommandBridge.showMainWindow()
    }

    @objc private func openCompactPanel() {
        CompactPanelController.shared.show()
    }

    @objc private func resetStuckKeys() {
        ModifierKeySafety.releaseShortcutModifiers()
    }

    private func showLayoutPresetChooser() {
        let screen = WindowLayoutStore.screenUnderMouse()
        modeChooserPresenter.show { mode in
            Task { @MainActor in
                _ = await WindowLayoutStore.activate(mode, targetScreen: screen)
            }
        }
    }

    private func layoutPresetsMenuItem() -> NSMenuItem {
        menuModes = WindowLayoutStore.loadModes()

        let item = NSMenuItem(title: "Apply Mode on This Display", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (index, mode) in menuModes.enumerated() {
            let modeItem = NSMenuItem(title: mode.name.rawValue, action: #selector(applyModeFromMenu(_:)), keyEquivalent: "")
            modeItem.target = self
            modeItem.tag = index
            submenu.addItem(modeItem)
        }

        if menuModes.isEmpty {
            let emptyItem = NSMenuItem(title: "No modes saved", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        }

        item.submenu = submenu
        return item
    }

    @objc private func applyModeFromMenu(_ sender: NSMenuItem) {
        guard menuModes.indices.contains(sender.tag) else { return }

        let mode = menuModes[sender.tag]
        let screen = WindowLayoutStore.screenUnderMouse()
        Task { @MainActor in
            _ = await WindowLayoutStore.activate(mode, targetScreen: screen)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func startBatteryItem() {
        guard batteryItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        if let button = item.button {
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            button.toolTip = "Battery remaining | used this week"
            button.target = self
            button.action = #selector(showBatteryStats)
        }

        batteryItem = item
        refreshBatteryItem()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryItem()
            }
        }
        batteryTimer?.tolerance = 0.2
        batteryPowerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryItem()
            }
        }
    }

    private func refreshBatteryItem() {
        guard let snapshot = BatteryUsageTracker.updateAndRead(),
              let button = batteryItem?.button else {
            batteryItem?.button?.title = "Battery"
            return
        }

        let remaining: String
        if snapshot.isCharging {
            remaining = "\(snapshot.remainingPercent)🔌"
        } else if snapshot.remainingPercent <= 20 {
            remaining = "\(snapshot.remainingPercent)🪫"
        } else {
            remaining = "\(snapshot.remainingPercent)%"
        }

        let used = snapshot.isCharging ? "\(snapshot.usedWeekPercent)🔋" : "\(snapshot.usedWeekPercent)%"
        button.title = "\(remaining) | \(used)"
        button.toolTip = snapshot.isCharging ? "Charging. Remaining | used this week" : "Battery remaining | used this week"
    }

    private func closeBatteryStats() {
        batteryStatsPanel?.orderOut(nil)
        batteryStatsPanel = nil
        removeBatteryStatsClickMonitors()
    }

    private func installBatteryStatsClickMonitors() {
        removeBatteryStatsClickMonitors()

        batteryStatsLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if self.batteryStatsPanelContains(event: event) {
                return event
            }
            self.closeBatteryStats()
            return event
        }

        batteryStatsGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closeBatteryStats()
            }
        }
    }

    private func removeBatteryStatsClickMonitors() {
        if let monitor = batteryStatsLocalMonitor {
            NSEvent.removeMonitor(monitor)
            batteryStatsLocalMonitor = nil
        }

        if let monitor = batteryStatsGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            batteryStatsGlobalMonitor = nil
        }
    }

    private func batteryStatsPanelContains(event: NSEvent) -> Bool {
        guard let panel = batteryStatsPanel,
              event.window === panel else {
            return false
        }

        let point = event.locationInWindow
        return panel.contentView?.bounds.contains(point) ?? false
    }

    @objc private func showBatteryStats() {
        guard let snapshot = BatteryUsageTracker.updateAndRead() else { return }

        if batteryStatsPanel != nil {
            closeBatteryStats()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 250),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: BatteryStatsPanelView(snapshot: snapshot))

        if let button = batteryItem?.button,
           let window = button.window {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenFrame = window.convertToScreen(buttonFrame)
            panel.setFrameOrigin(NSPoint(x: screenFrame.midX - 130, y: screenFrame.minY - 258))
        } else if let screen = NSScreen.main {
            panel.center()
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 280, y: frame.maxY - 260))
        }

        batteryStatsPanel = panel
        installBatteryStatsClickMonitors()
        panel.orderFrontRegardless()
    }

}

private struct BatteryStatsPanelView: View {
    let snapshot: BatteryUsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battery Used")
                .font(.system(size: 23, weight: .semibold))
                .padding(.top, 8)

            VStack(spacing: 10) {
                BatteryStatRow(title: "Today", value: snapshot.usedTodayPercent)
                BatteryStatRow(title: "This week", value: snapshot.usedWeekPercent)
                BatteryStatRow(title: "This month", value: snapshot.usedMonthPercent)
                BatteryStatRow(title: "This year", value: snapshot.usedYearPercent)
            }

            Divider()
                .padding(.top, 2)

            Text("Left menu bar number is remaining. Right number is total battery-percent-equivalent used this week.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 260, height: 250)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct BatteryStatRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.82))
            Spacer()
            Text("\(value)%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            MenuBarController.shared.start()
            CursorJumpController.shared.start()
            FileShelfController.shared.start()
            Desktop2Controller.shared.startIfNeeded()
            LoginItemStore.setEnabled(true, rememberChoice: false)
            if CommandLine.arguments.contains("--show-compact") {
                showCompactPanelForLaunchPreview()
            } else {
                hideInitialWindow()
            }
        }
    }

    @MainActor
    private func hideInitialWindow() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            NSApp.hide(nil)
        }
    }

    @MainActor
    private func showCompactPanelForLaunchPreview() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            for window in NSApp.windows where window.canBecomeMain {
                window.orderOut(nil)
            }
            CompactPanelController.shared.show()
        }
    }
}
