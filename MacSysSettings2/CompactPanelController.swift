//
//  CompactPanelController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import SwiftUI

@MainActor
final class CompactPanelController {
    static let shared = CompactPanelController()

    private let panelSize = NSSize(width: 372, height: 452)
    private var panel: CompactSettingsPanel?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    func show() {
        AppSurfaceStore.setLastSurface(.compact)
        let panel = makePanelIfNeeded()
        hideMainWindows(except: panel)
        panel.contentView = NSHostingView(rootView: CompactSettingsPanelView(onClose: { [weak self] in
            self?.hide()
        }))
        position(panel: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            panel.animator().alphaValue = 1
        }
        startOutsideClickMonitoring(for: panel)
    }

    func hide() {
        guard let panel else { return }
        stopOutsideClickMonitoring()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    func hideImmediately() {
        guard let panel else { return }
        stopOutsideClickMonitoring()
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func makePanelIfNeeded() -> CompactSettingsPanel {
        if let panel {
            return panel
        }

        let panel = CompactSettingsPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func hideMainWindows(except compactPanel: NSPanel) {
        for window in NSApp.windows where window !== compactPanel {
            guard window.canBecomeMain || window.title == "Mac Sys Settings 2" else { continue }
            window.orderOut(nil)
        }
    }

    private func position(panel: NSPanel) {
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }
        let margin: CGFloat = 14
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.maxX - panelSize.width - margin,
                y: screen.visibleFrame.maxY - panelSize.height - margin,
                width: panelSize.width,
                height: panelSize.height
            ),
            display: true
        )
    }

    private func startOutsideClickMonitoring(for panel: NSPanel) {
        stopOutsideClickMonitoring()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self, weak panel] event in
            guard let self, let panel else { return event }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self, weak panel] _ in
            Task { @MainActor in
                guard let self, let panel else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) {
                    self.hide()
                }
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }
}

private final class CompactSettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CompactSettingsPanelView: View {
    let onClose: () -> Void
    @State private var selectedSection: SettingsSection?
    @State private var appearance = AppAppearanceStore.current
    @ObservedObject private var voiceBackupController = VoiceBackupController.shared

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var compactSections: [SettingsSection] {
        SettingsSection.allCases.filter { $0 != .compactPanel }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let selectedSection {
                compactDetail(for: selectedSection)
            } else {
                homeGrid
            }
        }
        .frame(width: 372, height: 452)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            voiceBackupController.reloadFromFolder()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppAppearanceStore.didChangeNotification)) { _ in
            appearance = AppAppearanceStore.current
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if selectedSection != nil {
                Button {
                    selectedSection = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(CompactIconButtonStyle())
                .compactHoverHaptic()
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedSection?.title ?? "System Settings 2")
                    .font(.system(size: selectedSection == nil ? 21 : 15, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                if let selectedSection {
                    Text(selectedSection.subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                } else {
                    Text("Useful Mac controls Apple should have shipped.")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                toggleAppearance()
            } label: {
                CompactAppearanceToggleIcon(isDark: isDark)
            }
            .buttonStyle(.plain)
            .help(isDark ? "Switch Mac Sys Settings 2 to light mode" : "Switch Mac Sys Settings 2 to dark mode")
            .compactHoverHaptic()

            Button {
                onClose()
                AppCommandBridge.showMainWindow()
            } label: {
                Text("OPEN")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(CompactSmallTextButtonStyle())
            .compactHoverHaptic()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(CompactIconButtonStyle())
            .compactHoverHaptic()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(headerBackground)
    }

    private func toggleAppearance() {
        let nextMode: AppAppearanceMode = isDark ? .light : .dark
        appearance = nextMode
        AppAppearanceStore.setMode(nextMode)
    }

    private var homeGrid: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(compactSections) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            CompactSectionTile(section: section, isDark: isDark)
                        }
                        .buttonStyle(.plain)
                        .compactHoverHaptic()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }

        }
    }

    private func compactDetail(for section: SettingsSection) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                switch section {
                case .setup:
                    CompactButtonRow(title: "Accessibility", subtitle: "Move monitors, sizing, hide, switcher, hover focus, cursor jump, layouts.", value: AXIsProcessTrusted() ? "Allowed" : "Open") {
                        SettingsDeepLinks.openAccessibility()
                    }
                    CompactButtonRow(title: "Screen Recording", subtitle: "Window switcher thumbnails, browser tabs view, screenshot clipboard mode.", value: CGPreflightScreenCaptureAccess() ? "Allowed" : "Open") {
                        SettingsDeepLinks.openScreenRecording()
                    }
                    CompactButtonRow(title: "Input Monitoring", subtitle: "Option-Tab, Control-Arrow, Command-Option browser snap, autoscroll.", value: "Open") {
                        SettingsDeepLinks.openInputMonitoring()
                    }
                case .favorites:
                    CompactButtonRow(title: "Accessibility", subtitle: AXIsProcessTrusted() ? "Permission is already allowed." : "Open the macOS permission pane.", value: AXIsProcessTrusted() ? "Allowed" : "Open") {
                        SettingsDeepLinks.openAccessibility()
                    }
                    CompactButtonRow(title: "Displays", subtitle: "Arrangement, monitors, resolution, and refresh rate.", value: "Open") {
                        SettingsDeepLinks.openDisplays()
                    }
                    CompactButtonRow(title: "Sound", subtitle: "Input, output, AirPods mic, and audio routing.", value: "Open") {
                        SettingsDeepLinks.openSound()
                    }
                    CompactButtonRow(title: "Login Items", subtitle: "Apps that start when your Mac turns on.", value: LoginItemStore.isEnabled ? "App on" : "Open") {
                        SettingsDeepLinks.openLoginItems()
                    }
                case .weirdModes:
                    CompactButtonRow(title: "Fix safe weird modes", subtitle: "Release stuck modifiers and reset common accidental Mac modes.", value: "Fix") {
                        _ = WeirdMacModeStore.fixEverythingSafe()
                    }
                    CompactButtonRow(title: "Reset stuck keys", subtitle: "Release stuck Option, Control, Shift, Command, and Fn.", value: "Reset") {
                        _ = WeirdMacModeStore.fix(.stuckModifiers)
                    }
                    CompactButtonRow(title: "Open Accessibility", subtitle: "Check VoiceOver, Zoom, colors, and keyboard access.", value: "Open") {
                        WeirdMacModeStore.openSettings(for: .voiceOver)
                    }
                case .fun:
                    CompactToggleRow(title: "Slow-mo animations", subtitle: "Hold Shift while minimizing or restoring windows to see the old Mac slow-motion effect.", isOn: Binding(
                        get: { SlowMotionEffectsStore.isEnabled },
                        set: { SlowMotionEffectsStore.setEnabled($0) }
                    ))
                case .app:
                    CompactAppearancePicker(appearance: $appearance)
                    CompactToggleRow(title: "Open at login", subtitle: "Menu bar icon and shortcuts start with macOS.", isOn: Binding(
                        get: { LoginItemStore.isEnabled },
                        set: { _ = LoginItemStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Apple battery icon", subtitle: "Hidden so only our remaining and used-this-week tracker stays in the menu bar.", value: "Hidden") {
                        BatteryMenuStore.applyNativeBatteryVisibility()
                    }
                    CompactButtonRow(title: "Accessibility", subtitle: AXIsProcessTrusted() ? "Allowed" : "Needed for app/window control.", value: AXIsProcessTrusted() ? "Allowed" : "Open") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    CompactButtonRow(title: "Reset stuck keys", subtitle: "Release stuck shortcut modifiers.", value: "Reset") {
                        ModifierKeySafety.releaseShortcutModifiers()
                    }
                case .wallpaper:
                    CompactToggleRow(title: "Show Desktop 2", subtitle: "A borderless desktop layer with real folder tiles.", isOn: Binding(
                        get: { Desktop2Controller.shared.isVisible },
                        set: { newValue in
                            if newValue {
                                Desktop2Controller.shared.show()
                            } else {
                                Desktop2Controller.shared.hide()
                            }
                        }
                    ))
                    CompactButtonRow(title: "Add Desktop 2 folder", subtitle: "Create a real folder and show it on the desktop layer.", value: "\(Desktop2Controller.shared.folders.count)") {
                        Desktop2Controller.shared.addFolder()
                        Desktop2Controller.shared.show()
                    }
                case .personal:
                    CompactInfoBlock(title: "Personal Settings", subtitle: "Capture ideas for private/public settings before they become real modules.", value: "\(PersonalSettingsStore.load().count) ideas")
                case .downloads:
                    CompactToggleRow(title: "Preview new downloads", subtitle: "Show a small preview when files land in Downloads.", isOn: Binding(
                        get: { DownloadsPreviewStore.isEnabled },
                        set: { DownloadsPreviewStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Open Downloads in Finder", subtitle: "Open a tiny newest-first Downloads window when a file arrives.", isOn: Binding(
                        get: { DownloadsPreviewStore.opensFinderOnNewDownload },
                        set: { DownloadsPreviewStore.setOpensFinderOnNewDownload($0) }
                    ))
                case .clipboard:
                    CompactToggleRow(title: "Copy screenshots", subtitle: "Copy new screenshots to clipboard.", isOn: Binding(
                        get: { ScreenshotClipboardStore.isEnabled },
                        set: { ScreenshotClipboardStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Auto-clear latest screenshot", subtitle: "Clear our copied screenshot after the chosen delay.", isOn: Binding(
                        get: { ScreenshotClipboardStore.autoClearEnabled },
                        set: { ScreenshotClipboardStore.setAutoClearEnabled($0) }
                    ))
                case .history:
                    CompactButtonRow(title: "Check changes", subtitle: "Compare current app and macOS settings against the saved baseline.", value: "\(SettingsChangeHistoryStore.entries().count)") {
                        _ = SettingsChangeHistoryStore.checkNow()
                    }
                    CompactButtonRow(title: "Reset baseline", subtitle: "Mark the current setup as correct so future resets are easy to spot.", value: "Reset") {
                        SettingsChangeHistoryStore.resetBaseline()
                    }
                case .backup:
                    CompactButtonRow(title: "Export backup", subtitle: "Create a local Desktop backup folder for safe preference groups.", value: SettingsBackupStore.lastStatus) {
                        _ = SettingsBackupStore.exportBackup()
                    }
                    CompactButtonRow(title: "Show last backup", subtitle: SettingsBackupStore.lastBackupPath.isEmpty ? "No backup exported yet." : "Reveal the last backup folder.", value: "Show") {
                        SettingsBackupStore.revealLastBackup()
                    }
                case .workflows:
                    CompactButtonRow(title: "Start Work", subtitle: "Open the core work apps and apply Coding mode. Notifications stay on.", value: "Run") {
                        Task { @MainActor in
                            _ = await WorkflowShortcutStore.run(.startWork)
                        }
                    }
                    CompactButtonRow(title: "Meeting Mode", subtitle: "Open Meet/Zoom/Notes, set volume, and run the optional quiet shortcut.", value: "Run") {
                        Task { @MainActor in
                            _ = await WorkflowShortcutStore.run(.meetingMode)
                        }
                    }
                    CompactButtonRow(title: "Save Tonight", subtitle: "Save running apps for Restore Morning.", value: WorkflowShortcutStore.latestSnapshotSummary()) {
                        Task { @MainActor in
                            _ = await WorkflowShortcutStore.run(.saveTonight)
                        }
                    }
                case .agent:
                    CompactToggleRow(title: "Voice Backup", subtitle: "Save only real macOS mic sessions.", isOn: Binding(
                        get: { VoiceBackupStore.isEnabled },
                        set: { VoiceBackupStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Voice Backups folder", subtitle: VoiceBackupController.shared.directory.path, value: "Reveal") {
                        VoiceBackupController.shared.revealFolder()
                    }
                    CompactButtonRow(title: "Microphone privacy", subtitle: "Open macOS privacy and revoke mic access for apps you do not trust.", value: "Open") {
                        SettingsDeepLinks.openMicrophone()
                    }
                    if voiceBackupController.clips.isEmpty {
                        CompactInfoBlock(
                            title: "Recent backups",
                            subtitle: VoiceBackupStore.isEnabled ? "Start recording in Codex, ChatGPT, Wispr Flow, or another mic app." : "Turn Voice Backup on to start keeping mic-session backups.",
                            value: voiceBackupController.isRecording ? "Recording" : "Empty"
                        )
                    } else {
                        CompactInfoBlock(
                            title: "Recent backups",
                            subtitle: "Last three clips stay here until replaced or deleted.",
                            value: "\(voiceBackupController.clips.count)"
                        )
                        ForEach(voiceBackupController.clips) { clip in
                            CompactVoiceBackupClipRow(
                                clip: clip,
                                onTranscribe: { voiceBackupController.transcribe(clip) },
                                onCopyAudio: { voiceBackupController.copyClipFile(clip) },
                                onDelete: { confirmDeleteVoiceBackup(clip) }
                            )
                        }
                    }
                case .presentation:
                    CompactToggleRow(title: "Cursor Highlight", subtitle: "Highlight clicks live during demos, meetings, recordings, and UX reviews.", isOn: Binding(
                        get: { ClickLightStore.isEnabled },
                        set: { ClickLightStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Test pulse", subtitle: "Fire a sample highlight at the current cursor position.", value: ClickLightController.shared.lastStatus) {
                        ClickLightController.shared.testPulse()
                    }
                    CompactInfoBlock(title: "Accessibility", subtitle: "Required to detect clicks outside this app.", value: AXIsProcessTrusted() ? "Allowed" : "Needed")
                case .finder:
                    CompactToggleRow(title: "Sort chooser shortcut", subtitle: "Control-Option-Command-S opens Finder sort choices.", isOn: Binding(
                        get: { FinderSortShortcutStore.isEnabled },
                        set: { FinderSortShortcutStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Open/Save folder defaults", subtitle: "Jump app file pickers to saved folders.", isOn: Binding(
                        get: { FilePickerDefaultFolderStore.isEnabled },
                        set: { FilePickerDefaultFolderStore.setEnabled($0) }
                    ))
                    CompactInfoBlock(title: "Saved app rules", subtitle: "Add or remove app-folder rules in the full Finder page.", value: "\(FilePickerDefaultFolderStore.rules().count)")
                case .shelf:
                    CompactToggleRow(title: "Mouse-flick shelf", subtitle: "Flick mouse or press Command-Option-Shift-Y to park files.", isOn: Binding(
                        get: { FileShelfStore.isEnabled },
                        set: { FileShelfStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Show shelf", subtitle: "Open the floating drop shelf now.", value: "Show") {
                        FileShelfStore.setEnabled(true)
                        FileShelfController.shared.showShelf()
                    }
                case .screen:
                    CompactToggleRow(title: "Control-Arrow sizing", subtitle: "Resize the window under the pointer.", isOn: Binding(
                        get: { ControlArrowSnapStore.isEnabled },
                        set: { ControlArrowSnapStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Cursor Jump", subtitle: "Command-F2 opens monitor and point picker.", isOn: Binding(
                        get: { CursorJumpStore.isEnabled },
                        set: { CursorJumpStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Cursor locator", subtitle: "Command-Shift-L shows a glowing ring around the cursor.", isOn: Binding(
                        get: { CursorJumpStore.locatorEnabled },
                        set: { CursorJumpStore.setLocatorEnabled($0) }
                    ))
                    CompactToggleRow(title: "Hover focus", subtitle: "Focus windows when your mouse hovers over them.", isOn: Binding(
                        get: { HoverFocusStore.isEnabled },
                        set: { HoverFocusStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Auto key press", subtitle: "\(AutoKeyPressStore.shortcut.displayText) repeats a chosen key until pressed again.", isOn: Binding(
                        get: { AutoKeyPressStore.isEnabled },
                        set: { AutoKeyPressStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Set auto key", subtitle: "Press key, then numpad seconds; it starts right away.", value: AutoKeyPressStore.targetKeyName) {
                        AutoKeyPressController.shared.configureAndStart()
                    }
                    CompactToggleRow(title: "Audio tab jump", subtitle: "\(AudioTabJumpStore.shortcut.displayText) focuses the browser tab playing sound.", isOn: Binding(
                        get: { AudioTabJumpStore.isEnabled },
                        set: { AudioTabJumpStore.setEnabled($0) }
                    ))
                    CompactButtonRow(title: "Jump to audio", subtitle: "Find the Chrome or Safari tab currently playing sound.", value: "Jump") {
                        AudioTabJumpController.shared.jumpToPlayingTab()
                    }
                case .windowSwitcher:
                    CompactToggleRow(title: "Option-Tab switcher", subtitle: "Switch real windows instead of only apps.", isOn: Binding(
                        get: { WindowSwitcherSettingsStore.enabled },
                        set: { WindowSwitcherSettingsStore.setEnabled($0) }
                    ))
                case .mic:
                    CompactToggleRow(title: "Bluetooth off during sleep", subtitle: "Stops sleeping Macs from stealing headphones. May affect Apple Watch unlock and Bluetooth wake.", isOn: Binding(
                        get: { BluetoothSleepStore.isEnabled },
                        set: { BluetoothSleepStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Mic Wi-Fi warning", subtitle: "Warn when speech starts and Wi-Fi is off.", isOn: Binding(
                        get: { MicNetworkWarningStore.isEnabled },
                        set: { MicNetworkWarningStore.setEnabled($0) }
                    ))
                    CompactInfoBlock(title: "Current input", subtitle: "Open the full app for live device selection.", value: "Open app")
                case .layouts:
                    CompactButtonRow(title: "Apply Coding mode", subtitle: "Arrange running apps using your saved Coding preset.", value: "Apply") {
                        Task { @MainActor in
                            if let mode = WindowLayoutStore.loadModes().first(where: { $0.name == .coding }) {
                                _ = await WindowLayoutStore.activate(mode, targetScreen: WindowLayoutStore.screenUnderMouse())
                            }
                        }
                    }
                    CompactInfoBlock(title: "Saved modes", subtitle: "Build and edit presets in the full app.", value: "\(WindowLayoutStore.loadModes().count)")
                case .compactPanel:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    private var isDark: Bool {
        switch appearance {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    private var panelBackground: some View {
        isDark ? Color.black.opacity(0.94) : Color.white.opacity(0.985)
    }

    private var headerBackground: some View {
        (isDark ? Color.black.opacity(0.24) : Color.white.opacity(0.92))
    }

    private var footerBackground: some View {
        (isDark ? Color.black.opacity(0.26) : Color.white.opacity(0.96))
    }

    private var primaryText: Color { isDark ? .white : Color.black.opacity(0.86) }
    private var secondaryText: Color { isDark ? Color.white.opacity(0.62) : Color.black.opacity(0.52) }
    private var borderColor: Color { isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.10) }

    private func confirmDeleteVoiceBackup(_ clip: VoiceBackupClip) {
        let alert = NSAlert()
        alert.messageText = "Delete voice backup?"
        alert.informativeText = "This permanently removes this temporary audio clip."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            voiceBackupController.deleteClip(clip)
        }
    }
}

private struct CompactSectionTile: View {
    let section: SettingsSection
    let isDark: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: section.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color.black.opacity(0.86))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDark ? .white : Color.black.opacity(0.86))
                    .lineLimit(1)
                Text(displaySubtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.50))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(height: 96)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDark ? Color.white.opacity(hovering ? 0.14 : 0.08) : Color.black.opacity(hovering ? 0.08 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(hovering ? Color.green.opacity(0.72) : (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)), lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }

    private var displayTitle: String {
        section == .app ? "General" : section.title
    }

    private var displaySubtitle: String {
        section == .app ? "Startup" : section.subtitle
    }
}

private struct CompactToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(10)
        .background(compactRowBackground)
    }
}

private struct CompactButtonRow: View {
    let title: String
    let subtitle: String
    let value: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(value, action: action)
                .buttonStyle(CompactTextButtonStyle())
                .compactHoverHaptic()
        }
        .padding(10)
        .background(compactRowBackground)
    }
}

private struct CompactInfoBlock: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(compactRowBackground)
    }
}

private struct CompactVoiceBackupClipRow: View {
    let clip: VoiceBackupClip
    let onTranscribe: () -> Void
    let onCopyAudio: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 46, height: 38)
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice backup")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("\(formattedDate(clip.createdAt)) • \(formattedDuration(clip.duration))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Text(clip.status)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .buttonStyle(CompactIconButtonStyle())
                .foregroundStyle(Color.red)
                .compactHoverHaptic()
            }

            if let transcript = clip.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.system(size: 10.8))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)

                Button("COPY TRANSCRIPT") {
                    copyTranscript(transcript)
                }
                .buttonStyle(CompactTextButtonStyle())
                .compactHoverHaptic()
            }

            HStack(spacing: 8) {
                Button("TRANSCRIBE", action: onTranscribe)
                    .buttonStyle(CompactTextButtonStyle())
                    .compactHoverHaptic()
                Button("COPY AUDIO", action: onCopyAudio)
                    .buttonStyle(CompactTextButtonStyle())
                    .compactHoverHaptic()
            }
        }
        .padding(10)
        .background(compactRowBackground)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        guard duration.isFinite else { return "0:00" }
        let seconds = max(0, Int(duration.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func copyTranscript(_ transcript: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
    }
}

private struct CompactAppearancePicker: View {
    @Binding var appearance: AppAppearanceMode

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Appearance")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Full app and compact panel use the same mode.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: $appearance) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 104)
            .onChange(of: appearance) { _, newValue in
                AppAppearanceStore.setMode(newValue)
            }
        }
        .padding(10)
        .background(compactRowBackground)
    }
}

private struct CompactAppearanceToggleIcon: View {
    let isDark: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isDark ? Color.white : Color.black)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(isDark ? Color.black : Color.white)
                .rotationEffect(.degrees(90))
            Circle()
                .strokeBorder(isDark ? Color.white.opacity(0.72) : Color.black.opacity(0.22), lineWidth: 1.2)
        }
        .frame(width: 28, height: 28)
        .shadow(color: Color.black.opacity(hovering ? 0.20 : 0.08), radius: hovering ? 8 : 3, y: 2)
        .scaleEffect(hovering ? 1.06 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityLabel(isDark ? "Switch to light mode" : "Switch to dark mode")
    }
}

private var compactRowBackground: some View {
    RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(Color.primary.opacity(0.055))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
}

private struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct CompactTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .foregroundStyle(configuration.isPressed ? Color.green : .primary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(configuration.isPressed ? Color.green.opacity(0.7) : Color.primary.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct CompactSmallTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.green : .primary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
    }
}

private struct CompactHoverHapticModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard hovering != isHovering else { return }
                isHovering = hovering
                if hovering {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
    }
}

private extension View {
    func compactHoverHaptic() -> some View {
        modifier(CompactHoverHapticModifier())
    }
}
