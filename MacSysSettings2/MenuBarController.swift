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
        ClickLightController.shared.start()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            switch AppSurfaceStore.lastSurface {
            case .main:
                AppCommandBridge.showMainWindow()
            case .compact:
                CompactPanelController.shared.show()
            }
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
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            button.toolTip = "Battery remaining | used this week"
            button.target = self
            button.action = #selector(showBatteryStats)
        }

        batteryItem = item
        refreshBatteryItem()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryItem()
            }
        }
        batteryTimer?.tolerance = 0.5
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
        button.toolTip = batteryTooltip(for: snapshot)
    }

    private func batteryTooltip(for snapshot: BatteryUsageSnapshot) -> String {
        let powerState = snapshot.isCharging ? "Charging" : "On battery"
        return """
        BATTERY USED
        \(powerState)

        REMAINING
        \(snapshot.remainingPercent)%

        TODAY
        \(snapshot.usedTodayPercent)%

        THIS WEEK
        \(snapshot.usedWeekPercent)%

        THIS MONTH
        \(snapshot.usedMonthPercent)%

        THIS YEAR
        \(snapshot.usedYearPercent)%

        Click for charts.
        """
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
            contentRect: NSRect(x: 0, y: 0, width: 510, height: 980),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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
            let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
            let targetX: CGFloat
            if visibleFrame.intersects(screenFrame) {
                targetX = screenFrame.midX - (panel.frame.width / 2)
            } else {
                targetX = visibleFrame.maxX - panel.frame.width - 20
            }
            let targetY = visibleFrame.intersects(screenFrame) ? screenFrame.minY - panel.frame.height - 8 : visibleFrame.maxY - panel.frame.height - 8
            panel.setFrameOrigin(clampedPanelOrigin(x: targetX, y: targetY, size: panel.frame.size, visibleFrame: visibleFrame))
        } else if let screen = NSScreen.main {
            panel.center()
            let frame = screen.visibleFrame
            panel.setFrameOrigin(clampedPanelOrigin(x: frame.maxX - panel.frame.width - 20, y: frame.maxY - panel.frame.height - 8, size: panel.frame.size, visibleFrame: frame))
        }

        batteryStatsPanel = panel
        installBatteryStatsClickMonitors()
        panel.orderFrontRegardless()
    }

    private func clampedPanelOrigin(x: CGFloat, y: CGFloat, size: CGSize, visibleFrame: CGRect) -> NSPoint {
        NSPoint(
            x: min(max(x, visibleFrame.minX + 12), visibleFrame.maxX - size.width - 12),
            y: min(max(y, visibleFrame.minY + 12), visibleFrame.maxY - size.height - 12)
        )
    }

}

private struct BatteryStatsPanelView: View {
    let snapshot: BatteryUsageSnapshot
    private let panelWidth: CGFloat = 510
    private let panelHeight: CGFloat = 980
    private let backgroundColor = Color(red: 0.0, green: 0.095, blue: 0.04)
    private let creamTextColor = Color(red: 0.93, green: 0.88, blue: 0.74)
    private let secondaryTextColor = Color(red: 0.93, green: 0.88, blue: 0.74).opacity(0.78)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Battery Used")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(creamTextColor)
                Text("Left menu bar number is battery remaining.\nRight menu bar number is battery used this week.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            BatteryTodayRow(value: snapshot.usedTodayPercent)

            BatteryUsageChartSection(
                title: "This week",
                description: highestWeekDescription(snapshot.weekBuckets),
                value: snapshot.usedWeekPercent,
                buckets: snapshot.weekBuckets,
                labels: ["M", "T", "W", "T", "F", "S", "S"]
            )

            BatteryUsageChartSection(
                title: "This month",
                description: highestMonthDescription(snapshot.monthBuckets),
                value: snapshot.usedMonthPercent,
                buckets: monthBucketsByThree(snapshot.monthBuckets),
                labels: monthLabels()
            )

            BatteryUsageChartSection(
                title: "This year",
                description: highestYearDescription(yearBuckets: snapshot.yearBuckets, monthBuckets: snapshot.monthBuckets),
                value: snapshot.usedYearPercent,
                buckets: snapshot.yearBuckets,
                labels: ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
            )
        }
        .padding(.top, 44)
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(width: panelWidth, height: panelHeight)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func monthBucketsByThree(_ buckets: [Int]) -> [Int] {
        var grouped: [Int] = []
        for start in stride(from: 0, to: buckets.count, by: 3) {
            if grouped.count == 9 {
                grouped.append(buckets[start...].reduce(0, +))
                break
            }
            grouped.append(buckets[start..<min(start + 3, buckets.count)].reduce(0, +))
        }
        return grouped
    }

    private func monthLabels() -> [String] {
        ["1", "4", "7", "10", "13", "16", "19", "22", "25", "30"]
    }

    private func highestWeekDescription(_ buckets: [Int]) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard let index = buckets.indices.max(by: { buckets[$0] < buckets[$1] }),
              names.indices.contains(index) else {
            return "Highest day: today"
        }
        return "Highest day: \(names[index])"
    }

    private func highestMonthDescription(_ buckets: [Int]) -> String {
        guard let index = buckets.indices.max(by: { buckets[$0] < buckets[$1] }) else {
            return "Highest day: today"
        }
        return "Highest day: \(index + 1)"
    }

    private func highestYearDescription(yearBuckets: [Int], monthBuckets: [Int]) -> String {
        let monthNames = Calendar.current.monthSymbols
        let monthIndex = yearBuckets.indices.max(by: { yearBuckets[$0] < yearBuckets[$1] }) ?? max(Calendar.current.component(.month, from: Date()) - 1, 0)
        let dayIndex = monthBuckets.indices.max(by: { monthBuckets[$0] < monthBuckets[$1] }) ?? max(Calendar.current.component(.day, from: Date()) - 1, 0)
        let month = monthNames.indices.contains(monthIndex) ? monthNames[monthIndex] : "this month"
        return "Highest month: \(month)\nHighest day: \(month) \(dayIndex + 1)"
    }
}

private struct BatteryTodayRow: View {
    let value: Int
    @State private var isHovering = false

    private let creamTextColor = Color(red: 0.93, green: 0.88, blue: 0.74)
    private let titleColor = Color(red: 0.93, green: 0.88, blue: 0.74).opacity(0.78)
    private let lightTextColor = Color(red: 0.06, green: 0.27, blue: 0.16)
    private let lightDescriptionColor = Color(red: 0.10, green: 0.34, blue: 0.20).opacity(0.72)
    private let hoverFillColor = Color(red: 0.97, green: 0.94, blue: 0.84)
    private let restingFillColor = Color.clear
    private let borderColor = Color(red: 0.93, green: 0.88, blue: 0.74).opacity(0.18)

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(isHovering ? lightTextColor : creamTextColor)
                Text("Battery used today.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHovering ? lightDescriptionColor : titleColor)
            }
            .padding(.leading, 3)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(String(value))
                    .font(.system(size: 35, weight: .bold))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(isHovering ? lightTextColor : creamTextColor)
            .padding(.trailing, 5)
        }
        .padding(.top, 15)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovering ? hoverFillColor : restingFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isHovering ? Color.clear : borderColor, lineWidth: 0.6)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct BatteryUsageChartSection: View {
    let title: String
    let description: String
    let value: Int
    let buckets: [Int]
    let labels: [String]

    @State private var isHovering = false

    private let creamTextColor = Color(red: 0.93, green: 0.88, blue: 0.74)
    private let darkTitleColor = Color(red: 0.93, green: 0.88, blue: 0.74).opacity(0.76)
    private let darkDescriptionColor = Color(red: 0.93, green: 0.88, blue: 0.74)
    private let darkBarColor = Color(red: 0.93, green: 0.88, blue: 0.74)
    private let lightTextColor = Color(red: 0.06, green: 0.27, blue: 0.16)
    private let lightDescriptionColor = Color(red: 0.10, green: 0.34, blue: 0.20).opacity(0.72)
    private let lightBarColor = Color(red: 0.07, green: 0.38, blue: 0.19)
    private let hoverFillColor = Color(red: 0.97, green: 0.94, blue: 0.84)
    private let restingFillColor = Color.clear
    private let borderColor = Color(red: 0.93, green: 0.88, blue: 0.74).opacity(0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(isHovering ? lightTextColor : creamTextColor)
                    Text(description)
                        .font(.system(size: descriptionFontSize, weight: .semibold))
                        .foregroundStyle(isHovering ? lightDescriptionColor : darkDescriptionColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 3)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(value))
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(isHovering ? lightTextColor : creamTextColor)
                .padding(.trailing, 5)
            }

            VStack(spacing: 5) {
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(buckets.indices, id: \.self) { index in
                        VStack(spacing: 5) {
                            Text("\(buckets[index])")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isHovering ? lightTextColor.opacity(0.82) : creamTextColor)
                                .fixedSize(horizontal: true, vertical: false)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(isHovering ? lightBarColor : darkBarColor)
                                .frame(height: barHeight(for: buckets[index]))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 126, alignment: .bottom)
                        .contentShape(Rectangle())
                    }
                }
                .frame(height: 126, alignment: .bottom)

                HStack(spacing: barSpacing) {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isHovering ? lightTextColor.opacity(0.82) : creamTextColor)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, 15)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovering ? hoverFillColor : restingFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(isHovering ? Color.clear : borderColor, lineWidth: 0.6)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var descriptionFontSize: CGFloat {
        title == "This year" ? 12 : 13
    }

    private var barSpacing: CGFloat {
        buckets.count > 20 ? 4 : 8
    }

    private func barHeight(for value: Int) -> CGFloat {
        let maxValue = max(buckets.max() ?? 0, 1)
        let ratio = CGFloat(value) / CGFloat(maxValue)
        return max(value > 0 ? 10 : 5, 10 + (ratio * 84))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let micNetworkWarningController = MicNetworkWarningController.shared
    private let screenShortcutController = ScreenShortcutController.shared
    private let bluetoothSleepController = BluetoothSleepController.shared
    private let audioTabJumpController = AudioTabJumpController.shared
    private let clickLightController = ClickLightController.shared
    private let pinWindowController = PinWindowController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            MenuBarController.shared.start()
            screenShortcutController.start()
            audioTabJumpController.start()
            clickLightController.start()
            pinWindowController.start()
            CursorJumpController.shared.start()
            FileShelfController.shared.start()
            Desktop2Controller.shared.startIfNeeded()
            micNetworkWarningController.start()
            bluetoothSleepController.start()
            SettingsChangeHistoryController.shared.start()
            AppAppearanceExceptionStore.applyAllExceptions()
            AppAppearanceExceptionStore.applyNotesLightBackgroundIfEnabled()
            LoginItemStore.enableByDefaultIfNeeded()
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
            for window in NSApp.windows where window.canBecomeMain {
                window.orderOut(nil)
            }
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
