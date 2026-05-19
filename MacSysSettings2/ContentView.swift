//
//  ContentView.swift
//  MacSysSettings2
//
//  Created by Rishabh on 07/04/26.
//

import AppKit
import ApplicationServices
import Combine
import CoreAudio
import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: MuteMediaCoordinator
    @State private var selection: SettingsSection = .app

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
                .frame(width: 226)
                .background(SidebarBackground())

            Divider()

            SettingsDetailView(selection: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 790, idealWidth: 790, minHeight: 560)
        .background(WindowFrameConfigurator(targetWidth: 790))
    }
}

#Preview {
    ContentView(coordinator: MuteMediaCoordinator())
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case app
    case screen
    case mic
    case layouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "App Settings"
        case .screen: return "Screen"
        case .mic: return "Mic"
        case .layouts: return "Layouts"
        }
    }

    var subtitle: String {
        switch self {
        case .app: return "Startup and permissions"
        case .screen: return "Window shortcuts"
        case .mic: return "Input routing"
        case .layouts: return "Preset builder"
        }
    }

    var iconName: String {
        switch self {
        case .app: return "sparkles"
        case .screen: return "rectangle.connected.to.line.below"
        case .mic: return "mic.fill"
        case .layouts: return "rectangle.3.group.fill"
        }
    }

    var iconGradient: [Color] {
        switch self {
        case .app:
            return [Color(red: 0.50, green: 0.42, blue: 0.90), Color(red: 0.25, green: 0.36, blue: 0.78)]
        case .screen:
            return [Color(red: 0.32, green: 0.66, blue: 0.95), Color(red: 0.12, green: 0.45, blue: 0.82)]
        case .mic:
            return [Color(red: 0.27, green: 0.76, blue: 0.58), Color(red: 0.10, green: 0.52, blue: 0.45)]
        case .layouts:
            return [Color(red: 0.86, green: 0.55, blue: 0.24), Color(red: 0.68, green: 0.32, blue: 0.15)]
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Search")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.52))
                )

                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.92), Color(red: 0.55, green: 0.36, blue: 0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("R")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rishabh Sharma")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Local Mac")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        SidebarRow(section: section, isSelected: selection == section)
                            .onTapGesture {
                                selection = section
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct SidebarBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [Color.white.opacity(0.28), Color.white.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(Color.black.opacity(0.035))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 1)
                }
        }
    }
}

private struct SidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected ? [Color.white.opacity(0.28), Color.white.opacity(0.14)] : section.iconGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: section.iconName)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
            }
            .frame(width: 19, height: 19)

            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(section.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(red: 0.19, green: 0.63, blue: 0.35) : .clear)
        )
    }
}

private struct SettingsDetailView: View {
    let selection: SettingsSection

    var body: some View {
        switch selection {
        case .app:
            AppSettingsDetailView()
        case .screen:
            ScreenSettingsDetailView()
        case .mic:
            MicSettingsDetailView()
        case .layouts:
            LayoutSettingsDetailView()
        }
    }
}

private struct AppSettingsDetailView: View {
    @State private var launchAtLogin = LoginItemStore.isEnabled
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    var body: some View {
        SettingsPage(title: "App Settings", subtitle: "Keep the app available and ready to run real system actions.") {
            SettingsSectionBlock(
                title: "Startup",
                subtitle: "Controls that make this app available before you start using your Mac."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Open Mac Sys Settings 2 at login",
                        subtitle: "Add this app to Login Items so shortcuts are ready after your Mac starts."
                    ) {
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { _, newValue in
                                launchAtLogin = LoginItemStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Permissions",
                subtitle: "Required access for settings that control other apps or windows."
            ) {
                SettingsGroup {
                    SettingsActionRow(
                        title: "Accessibility access",
                        subtitle: accessibilityTrusted ? "Allowed. Window management shortcuts can control app windows." : "Required for moving and resizing other apps.",
                        value: accessibilityTrusted ? "Allowed" : "Needs access",
                        buttonTitle: "Open"
                    ) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: "A quick readout of the app features that are active right now."
            ) {
                StatusGrid(items: [
                    StatusItem(title: "App", value: "Running", state: .good),
                    StatusItem(title: "Login Item", value: launchAtLogin ? "On" : "Off", state: launchAtLogin ? .good : .warning),
                    StatusItem(title: "Accessibility", value: accessibilityTrusted ? "Allowed" : "Off", state: accessibilityTrusted ? .good : .warning)
                ])
            }
        }
        .onAppear {
            LoginItemStore.enableByDefaultIfNeeded()
            launchAtLogin = LoginItemStore.isEnabled
            accessibilityTrusted = AXIsProcessTrusted()
        }
    }
}

private struct ScreenSettingsDetailView: View {
    @State private var shortcut = ScreenShortcut.current()
    @State private var spaceSwitchingEnabled = SpaceSwitchShortcutStore.isEnabled
    @State private var controlArrowSnapEnabled = ControlArrowSnapStore.isEnabled
    @State private var displayCount = NSScreen.screens.count

    var body: some View {
        SettingsPage(title: "Screen", subtitle: "Resize windows and move the active app with global shortcuts.") {
            SettingsSectionBlock(
                title: "Move Between Monitors",
                subtitle: "Move the frontmost app window to another display while preserving edge alignment and usable size."
            ) {
                SettingsGroup {
                    ShortcutRecorderRow(shortcut: $shortcut)

                    Divider()

                    SettingsInfoRow(
                        title: "Move active app between monitors",
                        subtitle: "Press \(shortcut.displayText). The shortcut is always active while this app is running.",
                        value: displayCount > 1 ? "\(displayCount) displays" : "One display"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Window Sizing",
                subtitle: "Use arrow-key shortcuts to resize the active window into clean left or right layouts."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Control-Arrow window sizing",
                        subtitle: "Control-Left and Control-Right cycle the active window through half, one-third, and two-thirds."
                    ) {
                        Toggle("", isOn: $controlArrowSnapEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: controlArrowSnapEnabled) { _, newValue in
                                ControlArrowSnapStore.setEnabled(newValue)
                                if newValue {
                                    spaceSwitchingEnabled = SpaceSwitchShortcutStore.isEnabled
                                }
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Control-Arrow changes Spaces",
                        subtitle: spaceSwitchingEnabled
                            ? "macOS currently owns Control-Left and Control-Right for Spaces."
                            : "Control-Left and Control-Right are released from macOS Spaces."
                    ) {
                        Toggle("", isOn: $spaceSwitchingEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: spaceSwitchingEnabled) { _, newValue in
                                spaceSwitchingEnabled = SpaceSwitchShortcutStore.setEnabled(newValue)
                                if spaceSwitchingEnabled {
                                    controlArrowSnapEnabled = false
                                    ControlArrowSnapStore.setEnabled(false)
                                }
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: "Shows which screen shortcuts are active without opening macOS settings."
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Move Shortcut", value: shortcut.displayText, state: .good),
                    StatusItem(title: "Sizing", value: controlArrowSnapEnabled ? "On" : "Off", state: controlArrowSnapEnabled ? .good : .warning),
                    StatusItem(title: "Spaces Shortcut", value: spaceSwitchingEnabled ? "On" : "Off", state: spaceSwitchingEnabled ? .warning : .good)
                ])
            }
        }
        .onAppear {
            shortcut = ScreenShortcut.current()
            spaceSwitchingEnabled = SpaceSwitchShortcutStore.isEnabled
            controlArrowSnapEnabled = ControlArrowSnapStore.isEnabled
            displayCount = NSScreen.screens.count
        }
    }
}

private struct MicSettingsDetailView: View {
    @State private var devices = AudioInputStore.inputDevices()
    @State private var defaultDevice = AudioInputStore.defaultInputDevice()
    @State private var knownDeviceIDs: Set<AudioObjectID> = Set(AudioInputStore.inputDevices().map(\.id))
    @State private var detectedDevice: AudioInputDevice?
    @State private var newMicPromptsEnabled = true
    @State private var lastResult = "Ready"
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        SettingsPage(title: "Mic", subtitle: "Detect new microphones and switch the Mac input device from one place.") {
            SettingsSectionBlock(
                title: "New Mic Detection",
                subtitle: "When a new input device appears, show a centered choice instead of making you dig through System Settings."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Ask when a new mic connects",
                        subtitle: "Show a translucent overlay with choices to use the new mic, ignore it, or open macOS Sound settings."
                    ) {
                        Toggle("", isOn: $newMicPromptsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }

            SettingsSectionBlock(
                title: "Input Device",
                subtitle: "Choose the default microphone used by macOS. Per-app routing can be added later where apps expose controls."
            ) {
                SettingsGroup {
                    ForEach(devices) { device in
                        SettingsActionRow(
                            title: device.name,
                            subtitle: device.id == defaultDevice?.id ? "Current default input." : "Available microphone.",
                            value: device.id == defaultDevice?.id ? "Default" : "",
                            buttonTitle: device.id == defaultDevice?.id ? "Using" : "Use"
                        ) {
                            setDefault(device)
                        }

                        if device.id != devices.last?.id {
                            Divider()
                        }
                    }

                    if devices.isEmpty {
                        SettingsInfoRow(title: "No input devices found", subtitle: "Connect a microphone and refresh the list.", value: "")
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: "A quick readout of mic detection and routing."
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Default Mic", value: defaultDevice?.name ?? "None", state: defaultDevice == nil ? .warning : .good),
                    StatusItem(title: "Inputs", value: "\(devices.count)", state: devices.isEmpty ? .warning : .good),
                    StatusItem(title: "Last Action", value: lastResult, state: .good)
                ])
            }
        }
        .overlay {
            if let detectedDevice, newMicPromptsEnabled {
                MicDetectedOverlay(device: detectedDevice) {
                    setDefault(detectedDevice)
                    self.detectedDevice = nil
                } onIgnore: {
                    lastResult = "Ignored"
                    self.detectedDevice = nil
                } onSettings: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .onAppear {
            refreshDevices()
        }
        .onReceive(timer) { _ in
            refreshDevices(detectNewDevices: true)
        }
    }

    private func setDefault(_ device: AudioInputDevice) {
        if AudioInputStore.setDefaultInputDevice(device) {
            lastResult = "Switched"
            refreshDevices()
        } else {
            lastResult = "Failed"
        }
    }

    private func refreshDevices(detectNewDevices: Bool = false) {
        let latest = AudioInputStore.inputDevices()
        let latestIDs = Set(latest.map(\.id))

        if detectNewDevices, newMicPromptsEnabled {
            let newIDs = latestIDs.subtracting(knownDeviceIDs)
            if let newDevice = latest.first(where: { newIDs.contains($0.id) }) {
                detectedDevice = newDevice
            }
        }

        devices = latest
        defaultDevice = AudioInputStore.defaultInputDevice()
        knownDeviceIDs = latestIDs
    }
}

private struct MicDetectedOverlay: View {
    let device: AudioInputDevice
    let onUse: () -> Void
    let onIgnore: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("New mic detected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(device.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.82))

                HStack(spacing: 10) {
                    Button("Use for All Apps", action: onUse)
                    Button("Ignore", action: onIgnore)
                    Button("Mic Settings", action: onSettings)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
        }
    }
}

private struct LayoutSettingsDetailView: View {
    @State private var preset: LayoutPresetName = .coding
    @State private var rules = WindowLayoutStore.defaultRules(for: .coding)
    @State private var lastResult = "Ready"

    var body: some View {
        SettingsPage(title: "Layouts", subtitle: "Build intentional app layouts from rules instead of saving a messy desktop.") {
            SettingsSectionBlock(
                title: "Preset",
                subtitle: "Choose a named setup, then define the apps, screen, alignment, and size each rule should apply."
            ) {
                SettingsGroup {
                    SettingsPickerRow(title: "Preset name", subtitle: "Switch between starter layouts.", value: $preset) {
                        ForEach(LayoutPresetName.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .onChange(of: preset) { _, newValue in
                        rules = WindowLayoutStore.defaultRules(for: newValue)
                        lastResult = "Loaded"
                    }
                }
            }

            SettingsSectionBlock(
                title: "Rules",
                subtitle: "Each row says which app should go where when you apply this layout."
            ) {
                SettingsGroup {
                    ForEach($rules) { $rule in
                        LayoutRuleEditor(rule: $rule)

                        if rule.id != rules.last?.id {
                            Divider()
                        }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Apply Layout",
                subtitle: "Applies the rules to currently running apps. Missing apps are reported without changing the other rules."
            ) {
                SettingsGroup {
                    SettingsActionRow(
                        title: "Apply \(preset.rawValue)",
                        subtitle: "Move and resize running apps according to the rules above.",
                        value: lastResult,
                        buttonTitle: "Apply"
                    ) {
                        lastResult = WindowLayoutStore.apply(rules).joined(separator: ", ")
                    }
                }
            }
        }
    }
}

private struct LayoutRuleEditor: View {
    @Binding var rule: WindowLayoutRule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsPickerRow(title: "App", subtitle: "The running app this rule controls.", value: $rule.appName) {
                ForEach(WindowLayoutStore.appChoices, id: \.self) { appName in
                    Text(appName).tag(appName)
                }
            }

            HStack(spacing: 10) {
                Picker("Screen", selection: $rule.screen) {
                    ForEach(LayoutScreenTarget.allCases) { screen in
                        Text(screen.rawValue).tag(screen)
                    }
                }
                .labelsHidden()

                Picker("Position", selection: $rule.position) {
                    ForEach(LayoutPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .labelsHidden()

                Picker("Size", selection: $rule.size) {
                    ForEach(LayoutSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .labelsHidden()
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsPickerRow<Value: Hashable, Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var value: Value
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer(minLength: 12)
            Picker(title, selection: $value) {
                content
            }
            .labelsHidden()
            .frame(width: 168)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                content

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsSectionBlock<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SettingsToggleRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let value: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct RowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusItem: Identifiable {
    enum State {
        case good
        case warning
    }

    let id = UUID()
    let title: String
    let value: String
    let state: State
}

private struct StatusGrid: View {
    let items: [StatusItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.state == .good ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)

                        Text(item.title)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.value)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
}

private struct ShortcutRecorderRow: View {
    @Binding var shortcut: ScreenShortcut
    @State private var isRecording = false
    @State private var draftParts: [String] = []
    @State private var eventMonitor: Any?

    private var visibleParts: [String] {
        isRecording ? draftParts : shortcut.parts
    }

    var body: some View {
        HStack(spacing: 16) {
            RowText(
                title: "Move shortcut",
                subtitle: isRecording ? "Press a two or three key shortcut." : "Click the keys to record a new shortcut."
            )

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        ShortcutKeyBox(
                            text: visibleParts.indices.contains(index) ? visibleParts[index] : "",
                            isActive: isRecording && index == min(draftParts.count, 2)
                        )
                    }
                }
                .padding(2)
                .background(ShortcutCaptureView(isRecording: isRecording) { recordedShortcut in
                    draftParts = recordedShortcut.parts
                    shortcut = recordedShortcut
                    shortcut.save()
                    isRecording = false
                })
                .onTapGesture {
                    draftParts = []
                    isRecording = true
                }

                Button {
                    draftParts = []
                    isRecording = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Reset and record again")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onChange(of: isRecording) { _, isRecording in
            if isRecording {
                startRecordingMonitor()
            } else {
                stopRecordingMonitor()
            }
        }
        .onDisappear {
            stopRecordingMonitor()
        }
    }

    private func startRecordingMonitor() {
        stopRecordingMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let recordedShortcut = ScreenShortcut.from(event: event), recordedShortcut.isUsable else {
                return event
            }

            draftParts = recordedShortcut.parts
            shortcut = recordedShortcut
            shortcut.save()
            isRecording = false
            return nil
        }
    }

    private func stopRecordingMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

private struct ShortcutKeyBox: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(text.isEmpty ? .secondary : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(width: 66, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.16) : Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.8) : Color.black.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let isRecording: Bool
    let onShortcut: (ScreenShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onShortcut = onShortcut
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.isRecording = isRecording

        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    var isRecording = false
    var onShortcut: ((ScreenShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording, let shortcut = ScreenShortcut.from(event: event), shortcut.isUsable else {
            super.keyDown(with: event)
            return
        }

        onShortcut?(shortcut)
    }
}

private struct WindowFrameConfigurator: NSViewRepresentable {
    let targetWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView)
        }
    }

    private func configure(_ view: NSView) {
        guard let window = view.window else {
            DispatchQueue.main.async {
                configure(view)
            }
            return
        }

        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let visibleFrame = screen.visibleFrame
        let targetHeight = visibleFrame.height

        window.minSize = NSSize(width: targetWidth, height: min(targetHeight, 720))

        var frame = window.frame
        let needsWidthUpdate = abs(frame.width - targetWidth) > 1
        let needsHeightUpdate = frame.height < min(targetHeight, 720)

        guard needsWidthUpdate || needsHeightUpdate else { return }

        frame.size.width = targetWidth
        frame.size.height = min(targetHeight, max(720, frame.height))
        frame.origin.x = visibleFrame.midX - (targetWidth / 2)
        frame.origin.y = visibleFrame.maxY - frame.height

        window.setFrame(frame, display: true, animate: false)
    }
}
