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

    func show() {
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
    }

    func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.10
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    func hideImmediately() {
        guard let panel else { return }
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
}

private final class CompactSettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CompactSettingsPanelView: View {
    let onClose: () -> Void
    @State private var selectedSection: SettingsSection?
    @State private var appearance = AppAppearanceStore.current

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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .preferredColorScheme(appearance.colorScheme)
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
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedSection?.title ?? "System Settings 2")
                    .font(.system(size: selectedSection == nil ? 19 : 15, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                if let selectedSection {
                    Text(selectedSection.subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                onClose()
                AppCommandBridge.showMainWindow()
            } label: {
                Text("Open")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(CompactSmallTextButtonStyle())

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(CompactIconButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(headerBackground)
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
                case .app:
                    CompactAppearancePicker(appearance: $appearance)
                    CompactToggleRow(title: "Open at login", subtitle: "Menu bar icon and shortcuts start with macOS.", isOn: Binding(
                        get: { LoginItemStore.isEnabled },
                        set: { _ = LoginItemStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Hide Apple battery icon", subtitle: "Use only the Mac Sys Settings 2 battery tracker in the menu bar.", isOn: Binding(
                        get: { BatteryMenuStore.hidesNativeBatteryIcon },
                        set: { _ = BatteryMenuStore.setHidesNativeBatteryIcon($0) }
                    ))
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
                case .finder:
                    CompactToggleRow(title: "Sort chooser shortcut", subtitle: "Control-Option-Command-S opens Finder sort choices.", isOn: Binding(
                        get: { FinderSortShortcutStore.isEnabled },
                        set: { FinderSortShortcutStore.setEnabled($0) }
                    ))
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
                    CompactToggleRow(title: "Hover focus", subtitle: "Focus windows when your mouse hovers over them.", isOn: Binding(
                        get: { HoverFocusStore.isEnabled },
                        set: { HoverFocusStore.setEnabled($0) }
                    ))
                case .windowSwitcher:
                    CompactToggleRow(title: "Option-Tab switcher", subtitle: "Switch real windows instead of only apps.", isOn: Binding(
                        get: { WindowSwitcherSettingsStore.enabled },
                        set: { WindowSwitcherSettingsStore.setEnabled($0) }
                    ))
                    CompactToggleRow(title: "Hot corner switcher", subtitle: "Bottom-right corner opens the focused app switcher.", isOn: Binding(
                        get: { WindowSwitcherSettingsStore.bottomRightHotCorner },
                        set: { WindowSwitcherSettingsStore.setBottomRightHotCorner($0) }
                    ))
                case .mic:
                    CompactToggleRow(title: "Bluetooth mic prompt", subtitle: "Show sound input choices when audio devices connect.", isOn: Binding(
                        get: { BluetoothAudioInputPromptStore.isEnabled },
                        set: { BluetoothAudioInputPromptStore.setEnabled($0) }
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isDark ? Color.black.opacity(0.88) : Color.white.opacity(0.985))
            .background(isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    .foregroundStyle(
                        LinearGradient(colors: section.iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isDark ? Color.white.opacity(0.38) : Color.black.opacity(0.34))
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDark ? Color.white.opacity(hovering ? 0.14 : 0.08) : Color.black.opacity(hovering ? 0.08 : 0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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

private var compactRowBackground: some View {
    RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(Color.primary.opacity(0.055))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
}

private struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
    }
}
