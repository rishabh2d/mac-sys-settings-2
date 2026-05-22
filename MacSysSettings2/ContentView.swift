//
//  ContentView.swift
//  MacSysSettings2
//
//  Created by Rishabh on 07/04/26.
//

import AppKit
import ApplicationServices
import Carbon
import Combine
import CoreAudio
import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: MuteMediaCoordinator
    @ObservedObject var downloadsWatcherController: DownloadsWatcherController
    @ObservedObject var screenshotClipboardController: ScreenshotClipboardController
    @State private var selection: SettingsSection = .app
    @State private var appearance = AppAppearanceStore.current

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
                .frame(width: 223)
                .background(SidebarBackground())

            Divider()

            SettingsDetailView(
                selection: $selection,
                downloadsWatcherController: downloadsWatcherController,
                screenshotClipboardController: screenshotClipboardController
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SettingsColors.contentBackground)
        }
        .frame(minWidth: 720, idealWidth: 720, minHeight: 680)
        .background(WindowFrameConfigurator(targetWidth: 720))
        .preferredColorScheme(appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: AppAppearanceStore.didChangeNotification)) { _ in
            appearance = AppAppearanceStore.current
        }
    }
}

#Preview {
    ContentView(
        coordinator: MuteMediaCoordinator(),
        downloadsWatcherController: DownloadsWatcherController(),
        screenshotClipboardController: ScreenshotClipboardController()
    )
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case compactPanel
    case favorites
    case app
    case wallpaper
    case personal
    case downloads
    case clipboard
    case finder
    case shelf
    case screen
    case windowSwitcher
    case mic
    case layouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compactPanel: return "Compact Panel"
        case .favorites: return "Favorites"
        case .app: return "General"
        case .wallpaper: return "Wallpaper"
        case .personal: return "Personal"
        case .downloads: return "Downloads"
        case .clipboard: return "Clipboard"
        case .finder: return "Finder"
        case .shelf: return "Shelf"
        case .screen: return "Screen"
        case .windowSwitcher: return "Window Switcher"
        case .mic: return "Mic"
        case .layouts: return "Modes"
        }
    }

    var subtitle: String {
        switch self {
        case .compactPanel: return "Menu bar"
        case .favorites: return "Pinned"
        case .app: return "Startup"
        case .wallpaper: return "Desktop 2"
        case .personal: return "Custom ideas"
        case .downloads: return "Previews"
        case .clipboard: return "Screenshots"
        case .finder: return "Folder sorting"
        case .shelf: return "Park files"
        case .screen: return "Window shortcuts"
        case .windowSwitcher: return "Option-Tab"
        case .mic: return "Input"
        case .layouts: return "Focus layouts"
        }
    }

    var iconName: String {
        switch self {
        case .compactPanel: return "rectangle.inset.filled.and.person.filled"
        case .favorites: return "pin.fill"
        case .app: return "gearshape.fill"
        case .wallpaper: return "photo.on.rectangle.angled"
        case .personal: return "person.crop.circle.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .finder: return "folder.fill"
        case .shelf: return "tray.full.fill"
        case .screen: return "rectangle.on.rectangle"
        case .windowSwitcher: return "rectangle.stack.fill"
        case .mic: return "mic.fill"
        case .layouts: return "square.grid.2x2.fill"
        }
    }

    var iconGradient: [Color] {
        switch self {
        case .compactPanel:
            return [Color(red: 0.34, green: 0.84, blue: 0.58), Color(red: 0.13, green: 0.46, blue: 0.34)]
        case .favorites:
            return [Color(red: 1.0, green: 0.77, blue: 0.24), Color(red: 0.92, green: 0.45, blue: 0.10)]
        case .app:
            return [Color(red: 0.50, green: 0.42, blue: 0.90), Color(red: 0.25, green: 0.36, blue: 0.78)]
        case .wallpaper:
            return [Color(red: 0.17, green: 0.56, blue: 0.86), Color(red: 0.12, green: 0.30, blue: 0.45)]
        case .personal:
            return [Color(red: 0.94, green: 0.45, blue: 0.58), Color(red: 0.70, green: 0.22, blue: 0.42)]
        case .downloads:
            return [Color(red: 0.29, green: 0.59, blue: 0.94), Color(red: 0.12, green: 0.40, blue: 0.84)]
        case .clipboard:
            return [Color(red: 0.24, green: 0.70, blue: 0.78), Color(red: 0.11, green: 0.43, blue: 0.66)]
        case .finder:
            return [Color(red: 0.21, green: 0.62, blue: 0.92), Color(red: 0.10, green: 0.36, blue: 0.78)]
        case .shelf:
            return [Color(red: 0.58, green: 0.54, blue: 0.88), Color(red: 0.28, green: 0.34, blue: 0.70)]
        case .screen:
            return [Color(red: 0.32, green: 0.66, blue: 0.95), Color(red: 0.12, green: 0.45, blue: 0.82)]
        case .windowSwitcher:
            return [Color(red: 0.38, green: 0.49, blue: 0.92), Color(red: 0.22, green: 0.24, blue: 0.62)]
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Search")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SettingsColors.sidebarSearch)
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
                            .font(.system(size: 13, weight: .semibold))
                        Text("Apple Account")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 42)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            if section == .compactPanel {
                                CompactPanelController.shared.show()
                            } else {
                                selection = section
                            }
                        } label: {
                            SidebarRow(section: section, isSelected: selection == section)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section.title)
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct SidebarBackground: View {
    var body: some View {
        SettingsColors.sidebarBackground
    }
}

private struct SidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: section.iconGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: section.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.98))
            }
            .frame(width: 20, height: 20)

            Text(section.title)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? SettingsColors.sidebarSelection : .clear)
        )
    }
}

private struct SettingsDetailView: View {
    @Binding var selection: SettingsSection
    @ObservedObject var downloadsWatcherController: DownloadsWatcherController
    @ObservedObject var screenshotClipboardController: ScreenshotClipboardController

    var body: some View {
        switch selection {
        case .compactPanel:
            AppSettingsDetailView()
        case .favorites:
            FavoritesSettingsDetailView(selection: $selection)
        case .app:
            AppSettingsDetailView()
        case .wallpaper:
            WallpaperSettingsDetailView()
        case .personal:
            PersonalSettingsDetailView()
        case .downloads:
            DownloadsSettingsDetailView(controller: downloadsWatcherController)
        case .clipboard:
            ClipboardSettingsDetailView(controller: screenshotClipboardController)
        case .finder:
            FinderSettingsDetailView()
        case .shelf:
            ShelfSettingsDetailView()
        case .screen:
            ScreenSettingsDetailView()
        case .windowSwitcher:
            WindowSwitcherSettingsDetailView()
        case .mic:
            MicSettingsDetailView()
        case .layouts:
            ModesSettingsDetailView()
        }
    }
}

private struct FavoritesSettingsDetailView: View {
    @Binding var selection: SettingsSection

    var body: some View {
        SettingsPage(title: "Favorites", subtitle: "Pinned shortcuts to the settings you touch the most.") {
            SettingsSectionBlock(
                title: "Pinned System Settings",
                subtitle: "Open the macOS panes people usually hunt for first."
            ) {
                SettingsGroup {
                    FavoriteSystemSettingRow(
                        title: "Accessibility",
                        subtitle: "Grant control access for window, screen, keyboard, and hover features.",
                        value: AXIsProcessTrusted() ? "Allowed" : "Permission"
                    ) {
                        SettingsDeepLinks.openAccessibility()
                    }

                    FavoriteSystemSettingRow(
                        title: "Displays",
                        subtitle: "Arrangement, external monitors, resolution, refresh rate, and display options.",
                        value: "Open"
                    ) {
                        SettingsDeepLinks.openDisplays()
                    }

                    FavoriteSystemSettingRow(
                        title: "Sound",
                        subtitle: "Input and output devices, AirPods mic behavior, and system audio routing.",
                        value: "Open"
                    ) {
                        SettingsDeepLinks.openSound()
                    }

                    FavoriteSystemSettingRow(
                        title: "Login Items",
                        subtitle: "Choose what starts automatically when your Mac turns on.",
                        value: LoginItemStore.isEnabled ? "App on" : "Open"
                    ) {
                        SettingsDeepLinks.openLoginItems()
                    }
                }
            }

            SettingsSectionBlock(
                title: "Pinned Mac Sys Settings 2",
                subtitle: "Fast entry points into the real modules already wired in this app."
            ) {
                SettingsGroup {
                    FavoriteSystemSettingRow(
                        title: "Screen",
                        subtitle: "Window sizing, monitor moves, cursor jump, hover focus, and display shortcuts.",
                        value: "Open"
                    ) {
                        selection = .screen
                    }

                    FavoriteSystemSettingRow(
                        title: "Mic",
                        subtitle: "Choose sound input and show the Bluetooth audio input prompt.",
                        value: "Open"
                    ) {
                        selection = .mic
                    }
                }
            }
        }
    }
}

private struct FavoriteSystemSettingRow: View {
    let title: String
    let subtitle: String
    let value: String
    let action: () -> Void

    var body: some View {
        SettingsActionRow(
            title: title,
            subtitle: subtitle,
            value: value,
            buttonTitle: "Open",
            action: action
        )
    }
}

enum SettingsDeepLinks {
    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openDisplays() {
        open("x-apple.systempreferences:com.apple.Displays-Settings.extension")
    }

    static func openSound() {
        open("x-apple.systempreferences:com.apple.Sound-Settings.extension")
    }

    static func openLoginItems() {
        open("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
    }

    private static func open(_ rawValue: String) {
        guard let url = URL(string: rawValue) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct DownloadsSettingsDetailView: View {
    @ObservedObject var controller: DownloadsWatcherController
    @State private var previewsEnabled = DownloadsPreviewStore.isEnabled
    @State private var openFinderEnabled = DownloadsPreviewStore.opensFinderOnNewDownload

    var body: some View {
        SettingsPage(title: "Downloads", subtitle: "Control what happens the moment a new file lands in Downloads.") {
            SettingsSectionBlock(
                title: "New Download Actions",
                subtitle: "Choose whether new downloads appear as a quick preview, in Finder, or both."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Show preview",
                        subtitle: "Watch Downloads and show a draggable file preview in the bottom-right corner."
                    ) {
                        Toggle("", isOn: $previewsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: previewsEnabled) { _, newValue in
                                DownloadsPreviewStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Open Downloads newest first",
                        subtitle: "When a new file lands, open a tiny bottom-right Downloads window with no sidebar, sorted newest first, and select the new file."
                    ) {
                        Toggle("", isOn: $openFinderEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: openFinderEnabled) { _, newValue in
                                DownloadsPreviewStore.setOpensFinderOnNewDownload(newValue)
                            }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Finder behavior",
                        subtitle: "Finder is compacted each time this fires, so Downloads opens like a small corner window instead of the full sidebar view.",
                        value: openFinderEnabled ? "On" : "Off"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Watcher", value: controller.isWatching ? "On" : "Off", state: controller.isWatching ? .good : .warning),
                    StatusItem(title: "Preview", value: previewsEnabled ? "On" : "Off", state: previewsEnabled ? .good : .warning),
                    StatusItem(title: "Finder Open", value: openFinderEnabled ? "On" : "Off", state: openFinderEnabled ? .good : .warning),
                    StatusItem(title: "Last File", value: controller.lastStatus, state: (previewsEnabled || openFinderEnabled) ? .good : .warning)
                ])
            }
        }
        .onAppear {
            previewsEnabled = DownloadsPreviewStore.isEnabled
            openFinderEnabled = DownloadsPreviewStore.opensFinderOnNewDownload
        }
    }
}

private struct ClipboardSettingsDetailView: View {
    @ObservedObject var controller: ScreenshotClipboardController
    @State private var copyScreenshotsEnabled = ScreenshotClipboardStore.isEnabled
    @State private var autoClearEnabled = ScreenshotClipboardStore.autoClearEnabled
    @State private var autoClearMinutes = ScreenshotClipboardStore.autoClearMinutes

    private let clearChoices = [1, 5, 10, 30, 60]

    var body: some View {
        SettingsPage(title: "Clipboard", subtitle: "Copy new screenshots without filling your clipboard history by accident.") {
            SettingsSectionBlock(
                title: "Screenshot Clipboard",
                subtitle: "Off by default. When enabled, new macOS screenshots saved on Desktop are copied to the live clipboard so you can paste them immediately."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Copy new screenshots to clipboard",
                        subtitle: "Only watches normal macOS screenshot files on Desktop. Each new screenshot replaces the previous live clipboard screenshot."
                    ) {
                        Toggle("", isOn: $copyScreenshotsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: copyScreenshotsEnabled) { _, newValue in
                                ScreenshotClipboardStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Clear live clipboard after delay",
                        subtitle: "Clears the Mac clipboard only if it still contains the screenshot this app copied. If you copy anything else, we leave your clipboard alone."
                    ) {
                        Toggle("", isOn: $autoClearEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: autoClearEnabled) { _, newValue in
                                ScreenshotClipboardStore.setAutoClearEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsPickerRow(
                        title: "Clear after",
                        subtitle: "How long the latest copied screenshot stays available for paste, unless you copy something else first.",
                        value: $autoClearMinutes
                    ) {
                        ForEach(clearChoices, id: \.self) { minutes in
                            Text("\(minutes)m").tag(minutes)
                        }
                    }
                    .disabled(!autoClearEnabled)
                    .onChange(of: autoClearMinutes) { _, newValue in
                        ScreenshotClipboardStore.setAutoClearMinutes(newValue)
                    }
                }
            }

            SettingsSectionBlock(
                title: "Clipboard History Apps",
                subtitle: "Read this before turning it on if you use a clipboard manager."
            ) {
                SettingsGroup {
                    SettingsWarningRow(
                        title: "Clipboard managers can keep real image copies",
                        subtitle: "Raycast, Paste, CleanClip, Maccy, PastePal, Clipy, Alfred Clipboard History, LaunchBar, Keyboard Maestro, BetterTouchTool, CopyClip, Pastebot, Unclutter, iClip, ClipTools, and similar apps may save every screenshot this app places on the clipboard. That can mean one screenshot file on Desktop plus another saved image in clipboard history, so screenshot storage can effectively double for those copied screenshots."
                    )

                    Divider()

                    SettingsInfoRow(
                        title: "What this app can safely clear",
                        subtitle: "Mac Sys Settings 2 can clear the live macOS clipboard later if it still contains our copied screenshot. It cannot reliably delete image copies that another clipboard-history app already saved into its own history.",
                        value: "Live only"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Copy Mode", value: copyScreenshotsEnabled ? "On" : "Off", state: copyScreenshotsEnabled ? .good : .warning),
                    StatusItem(title: "Watcher", value: controller.isWatching ? "On" : "Off", state: controller.isWatching ? .good : .warning),
                    StatusItem(title: "Auto-clear", value: autoClearEnabled ? "\(autoClearMinutes)m" : "Off", state: autoClearEnabled ? .good : .warning),
                    StatusItem(title: "Last Screenshot", value: controller.lastCopiedFileName, state: controller.lastCopiedFileName == "None" ? .warning : .good),
                    StatusItem(title: "Status", value: controller.lastStatus, state: controller.isWatching ? .good : .warning)
                ])
            }
        }
        .onAppear {
            copyScreenshotsEnabled = ScreenshotClipboardStore.isEnabled
            autoClearEnabled = ScreenshotClipboardStore.autoClearEnabled
            autoClearMinutes = ScreenshotClipboardStore.autoClearMinutes
        }
    }
}

private struct FinderSettingsDetailView: View {
    @State private var sortShortcutEnabled = FinderSortShortcutStore.isEnabled

    var body: some View {
        SettingsPage(title: "Finder", subtitle: "") {
            SettingsSectionBlock(
                title: "Folder Sorting",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Control-Option-Command-S sort chooser",
                        subtitle: "Press Control-Option-Command-S while a Finder folder is open. Choose Date Created or Date Modified, then the front Finder folder updates."
                    ) {
                        Toggle("", isOn: $sortShortcutEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: sortShortcutEnabled) { _, newValue in
                                FinderSortShortcutStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Applies to front Finder window",
                        subtitle: "Works with icon and list views. If no Finder folder is open, the chooser asks you to open one first.",
                        value: sortShortcutEnabled ? "On" : "Off"
                    )
                }
            }
        }
        .onAppear {
            sortShortcutEnabled = FinderSortShortcutStore.isEnabled
        }
    }
}

private struct ShelfSettingsDetailView: View {
    @State private var shelfEnabled = FileShelfStore.isEnabled
    @State private var parkedCount = FileShelfStore.currentURLs().count

    var body: some View {
        SettingsPage(title: "Shelf", subtitle: "Temporarily park files while you move through Finder and apps.") {
            SettingsSectionBlock(
                title: "File Shelf",
                subtitle: "A small Yoink-style shelf appears when you flick the mouse or press the shortcut. Drop files into it, then drag them back out later."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Show shelf from mouse flick",
                        subtitle: "Fast mouse movement opens a floating drop shelf near the edge of the current monitor. It stores file references, not duplicate copies."
                    ) {
                        Toggle("", isOn: $shelfEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: shelfEnabled) { _, newValue in
                                FileShelfStore.setEnabled(newValue)
                                parkedCount = FileShelfStore.currentURLs().count
                            }
                    }

                    Divider()

                    SettingsActionRow(
                        title: "Manual shelf shortcut",
                        subtitle: "Press Command-Option-Shift-Y to show or hide the shelf. Use this if the mouse flick does not feel right yet.",
                        value: "Cmd-Opt-Shift-Y",
                        buttonTitle: "Show"
                    ) {
                        FileShelfStore.setEnabled(true)
                        shelfEnabled = true
                        FileShelfController.shared.showShelf()
                        parkedCount = FileShelfStore.currentURLs().count
                    }

                    Divider()

                    SettingsActionRow(
                        title: "Parked files",
                        subtitle: "Clear only removes items from the shelf. It does not delete the files from disk.",
                        value: "\(parkedCount)",
                        buttonTitle: "Clear"
                    ) {
                        FileShelfStore.clear()
                        parkedCount = 0
                    }
                }
            }

            SettingsSectionBlock(
                title: "How To Use",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsInfoRow(
                        title: "Drop files in",
                        subtitle: "Select or drag files from Finder, flick your mouse or press the shortcut, then drop them into the shelf.",
                        value: shelfEnabled ? "Ready" : "Off"
                    )

                    Divider()

                    SettingsInfoRow(
                        title: "Drag files out",
                        subtitle: "Drag a parked item from the shelf into Finder, an upload field, Mail, Messages, or another app.",
                        value: "Reference"
                    )
                }
            }
        }
        .onAppear {
            shelfEnabled = FileShelfStore.isEnabled
            parkedCount = FileShelfStore.currentURLs().count
        }
        .onReceive(NotificationCenter.default.publisher(for: FileShelfStore.didItemsChangeNotification)) { _ in
            parkedCount = FileShelfStore.currentURLs().count
        }
    }
}

private struct PersonalSettingsDetailView: View {
    @State private var requests = PersonalSettingsStore.load()
    @State private var lastAction = "Ready"

    private var readyCount: Int {
        requests.filter { $0.reviewState == .ready }.count
    }

    var body: some View {
        SettingsPage(title: "Personal", subtitle: "") {
            SettingsSectionBlock(
                title: "Personal Settings",
                subtitle: ""
            ) {
                SettingsGroup {
                    ForEach(requests) { request in
                        if let binding = binding(for: request) {
                            PersonalSettingEditor(request: binding) {
                                removeRequest(request)
                            }
                        }

                        if request.id != requests.last?.id {
                            Divider()
                        }
                    }

                    Divider()

                    SettingsActionRow(
                        title: "Add personal setting",
                        subtitle: "Add your own setting request before deciding whether it belongs in GitHub.",
                        value: "\(requests.count) items",
                        buttonTitle: "Add"
                    ) {
                        addRequest()
                    }
                }
            }

            SettingsSectionBlock(
                title: "GitHub Review",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsInfoRow(
                        title: "Ready to discuss",
                        subtitle: "Only items marked Ready should be considered for a GitHub push request.",
                        value: "\(readyCount)"
                    )

                    Divider()

                    SettingsActionRow(
                        title: "Mark all as needs detail",
                        subtitle: "Use this before a review pass when the personal list is still messy.",
                        value: lastAction,
                        buttonTitle: "Reset"
                    ) {
                        requests = requests.map { request in
                            var updated = request
                            updated.reviewState = .needsDetail
                            return updated
                        }
                        PersonalSettingsStore.save(requests)
                        lastAction = "Reset"
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Personal Items", value: "\(requests.count)", state: requests.isEmpty ? .warning : .good),
                    StatusItem(title: "Ready", value: "\(readyCount)", state: readyCount > 0 ? .good : .warning),
                    StatusItem(title: "GitHub Push", value: "Ask first", state: .good)
                ])
            }
        }
        .onAppear {
            requests = PersonalSettingsStore.load()
        }
    }

    private func binding(for request: PersonalSettingRequest) -> Binding<PersonalSettingRequest>? {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else { return nil }

        return Binding(
            get: { requests[index] },
            set: { updatedRequest in
                requests[index] = updatedRequest
                PersonalSettingsStore.save(requests)
            }
        )
    }

    private func addRequest() {
        requests.append(
            PersonalSettingRequest(
                title: "New personal setting",
                note: "Describe the behavior, permission needs, and what should happen.",
                category: .workflow,
                reviewState: .idea
            )
        )
        PersonalSettingsStore.save(requests)
        lastAction = "Added"
    }

    private func removeRequest(_ request: PersonalSettingRequest) {
        guard requests.count > 1 else { return }

        requests.removeAll { $0.id == request.id }
        PersonalSettingsStore.save(requests)
        lastAction = "Removed"
    }
}

private struct PersonalSettingEditor: View {
    @Binding var request: PersonalSettingRequest
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsTextFieldRow(title: "Name", subtitle: "The personal setting or feature request.", text: $request.title)
            SettingsTextFieldRow(title: "Notes", subtitle: "Keep exact behavior, permission notes, and edge cases here.", text: $request.note)

            HStack(spacing: 10) {
                Picker("Category", selection: $request.category) {
                    ForEach(PersonalSettingCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .labelsHidden()

                Picker("Review", selection: $request.reviewState) {
                    ForEach(PersonalSettingReviewState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .labelsHidden()

                Spacer()

                Button("Remove", action: onRemove)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct AppSettingsDetailView: View {
    @State private var launchAtLogin = LoginItemStore.isEnabled
    @State private var appearance = AppAppearanceStore.current
    @State private var fastMinimizeAnimation = DockMinimizeAnimationStore.isEnabled
    @State private var instantCommandM = InstantMinimizeStore.isEnabled
    @State private var minimizeEffect = DockMinimizeAnimationStore.currentEffect
    @State private var instantDockReveal = DockRevealStore.isEnabled
    @State private var dockRevealStatus = DockRevealStore.statusText
    @State private var dimHiddenDockApps = DockHiddenAppsStore.isEnabled
    @State private var hiddenDockAppsStatus = DockHiddenAppsStore.statusText
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var keyboardSafetyStatus = "Ready"
    @State private var hideNativeBatteryIcon = BatteryMenuStore.hidesNativeBatteryIcon

    var body: some View {
        SettingsPage(title: "General", subtitle: "") {
            SettingsSectionBlock(
                title: "Startup",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Turn app on when Mac starts",
                        subtitle: "Add Mac Sys Settings 2 to Login Items so the menu bar icon and shortcuts are ready after restart."
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
                title: "Battery Menu",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Hide Apple battery icon",
                        subtitle: "Optional step for the Mac Sys Settings 2 battery menu: hide macOS's original battery icon so the menu bar only shows our remaining/used-today tracker."
                    ) {
                        Toggle("", isOn: $hideNativeBatteryIcon)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: hideNativeBatteryIcon) { _, newValue in
                                hideNativeBatteryIcon = BatteryMenuStore.setHidesNativeBatteryIcon(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Appearance",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsPickerRow(
                        title: "Light and dark mode",
                        subtitle: "Choose System, Light, or Dark. The compact panel follows the same setting.",
                        value: $appearance
                    ) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: appearance) { _, newValue in
                        AppAppearanceStore.setMode(newValue)
                    }
                }
            }

            SettingsSectionBlock(
                title: "Permissions",
                subtitle: ""
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
                title: "Keyboard Safety",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsActionRow(
                        title: "Reset stuck keys",
                        subtitle: "Release shortcut modifier keys if macOS thinks Option, Control, Shift, Command, or Fn is still held.",
                        value: keyboardSafetyStatus,
                        buttonTitle: "Reset"
                    ) {
                        ModifierKeySafety.releaseShortcutModifiers()
                        keyboardSafetyStatus = "Reset sent"
                    }
                }
            }

            SettingsSectionBlock(
                title: "Window Animations",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Fast minimize animation",
                        subtitle: "Use macOS's faster Scale minimize effect. Turning this on restarts Dock once so the change applies."
                    ) {
                        Toggle("", isOn: $fastMinimizeAnimation)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: fastMinimizeAnimation) { _, newValue in
                                if DockMinimizeAnimationStore.setEnabled(newValue) {
                                    minimizeEffect = DockMinimizeAnimationStore.currentEffect
                                } else {
                                    fastMinimizeAnimation.toggle()
                                }
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Command-M instant minimize",
                        subtitle: "Press Command-M and Mac Sys Settings 2 catches it first, then minimizes the focused window immediately through Accessibility."
                    ) {
                        Toggle("", isOn: $instantCommandM)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: instantCommandM) { _, newValue in
                                InstantMinimizeStore.setEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsInfoRow(
                        title: "Current minimize effect",
                        subtitle: "Scale is the fast setting; Genie is the default macOS effect.",
                        value: minimizeEffect.capitalized
                    )
                }
            }

            SettingsSectionBlock(
                title: "Dock",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Instant Dock reveal",
                        subtitle: "For auto-hidden Dock users: set Dock reveal delay to zero and shorten the show/hide animation. Turning this on restarts Dock once."
                    ) {
                        Toggle("", isOn: $instantDockReveal)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: instantDockReveal) { _, newValue in
                                if DockRevealStore.setEnabled(newValue) {
                                    dockRevealStatus = DockRevealStore.statusText
                                } else {
                                    instantDockReveal.toggle()
                                }
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Dim hidden apps in Dock",
                        subtitle: "Make apps hidden with Command-H look translucent in Dock, so hidden apps are visually obvious. Turning this on restarts Dock once."
                    ) {
                        Toggle("", isOn: $dimHiddenDockApps)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: dimHiddenDockApps) { _, newValue in
                                if DockHiddenAppsStore.setEnabled(newValue) {
                                    hiddenDockAppsStatus = DockHiddenAppsStore.statusText
                                } else {
                                    dimHiddenDockApps.toggle()
                                }
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsActionRow(
                        title: "Restore Dock reveal defaults",
                        subtitle: "Remove Mac Sys Settings 2's Dock reveal timing tweaks and restart Dock.",
                        value: dockRevealStatus,
                        buttonTitle: "Restore"
                    ) {
                        if DockRevealStore.restoreDefaults() {
                            instantDockReveal = DockRevealStore.isEnabled
                            dockRevealStatus = DockRevealStore.statusText
                        }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "App", value: "Running", state: .good),
                    StatusItem(title: "Login Item", value: launchAtLogin ? "On" : "Off", state: launchAtLogin ? .good : .warning),
                    StatusItem(title: "Accessibility", value: accessibilityTrusted ? "Allowed" : "Off", state: accessibilityTrusted ? .good : .warning),
                    StatusItem(title: "Minimize", value: minimizeEffect.capitalized, state: fastMinimizeAnimation ? .good : .warning),
                    StatusItem(title: "Command-M", value: instantCommandM ? "Instant" : "System", state: instantCommandM ? .good : .warning),
                    StatusItem(title: "Apple Battery", value: hideNativeBatteryIcon ? "Hidden" : "Shown", state: hideNativeBatteryIcon ? .good : .warning),
                    StatusItem(title: "Dock Reveal", value: dockRevealStatus, state: instantDockReveal ? .good : .warning),
                    StatusItem(title: "Hidden Apps", value: hiddenDockAppsStatus, state: dimHiddenDockApps ? .good : .warning)
                ])
            }
        }
        .onAppear {
            LoginItemStore.enableByDefaultIfNeeded()
            launchAtLogin = LoginItemStore.isEnabled
            appearance = AppAppearanceStore.current
            fastMinimizeAnimation = DockMinimizeAnimationStore.isEnabled
            instantCommandM = InstantMinimizeStore.isEnabled
            minimizeEffect = DockMinimizeAnimationStore.currentEffect
            instantDockReveal = DockRevealStore.isEnabled
            dockRevealStatus = DockRevealStore.statusText
            dimHiddenDockApps = DockHiddenAppsStore.isEnabled
            hiddenDockAppsStatus = DockHiddenAppsStore.statusText
            accessibilityTrusted = AXIsProcessTrusted()
            hideNativeBatteryIcon = BatteryMenuStore.hidesNativeBatteryIcon
        }
    }
}

private struct WallpaperSettingsDetailView: View {
    @ObservedObject private var desktop2 = Desktop2Controller.shared
    @State private var launchAtStartup = Desktop2Store.launchAtStartup
    @State private var lastAction = "Ready"

    var body: some View {
        SettingsPage(title: "Wallpaper", subtitle: "Turn your normal desktop into a simple second layer.") {
            SettingsSectionBlock(
                title: "Desktop 2",
                subtitle: "A borderless desktop layer sits behind normal apps and holds real folders."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Show Desktop 2",
                        subtitle: "Creates a full-screen desktop layer with no window buttons, no Dock window, and folder tiles on top of the wallpaper."
                    ) {
                        Toggle("", isOn: Binding(
                            get: { desktop2.isVisible },
                            set: { newValue in
                                if newValue {
                                    desktop2.show()
                                    lastAction = "Shown"
                                } else {
                                    desktop2.hide()
                                    lastAction = "Hidden"
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Open Desktop 2 when app starts",
                        subtitle: "Restores the second desktop layer automatically the next time Mac Sys Settings 2 launches."
                    ) {
                        Toggle("", isOn: $launchAtStartup)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: launchAtStartup) { _, newValue in
                                Desktop2Store.setLaunchAtStartup(newValue)
                            }
                    }

                    Divider()

                    SettingsActionRow(
                        title: "Add folder",
                        subtitle: "Creates a real folder inside Desktop 2 storage and adds a tile to the desktop layer.",
                        value: "\(desktop2.folders.count)",
                        buttonTitle: "Add"
                    ) {
                        desktop2.addFolder()
                        desktop2.show()
                        lastAction = "Folder added"
                    }
                }
            }

            SettingsSectionBlock(
                title: "Folders",
                subtitle: "These open in Finder, because each tile is backed by a real folder."
            ) {
                SettingsGroup {
                    ForEach(desktop2.folders) { folder in
                        SettingsActionRow(
                            title: folder.name,
                            subtitle: folder.url.path,
                            value: "Folder",
                            buttonTitle: "Open"
                        ) {
                            desktop2.openFolder(folder)
                            lastAction = "Opened"
                        }

                        if folder.id != desktop2.folders.last?.id {
                            Divider()
                        }
                    }

                    if desktop2.folders.isEmpty {
                        SettingsInfoRow(
                            title: "No folders yet",
                            subtitle: "Use Add folder to create the first Desktop 2 folder.",
                            value: "Empty"
                        )
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Desktop 2", value: desktop2.isVisible ? "Visible" : "Hidden", state: desktop2.isVisible ? .good : .warning),
                    StatusItem(title: "Folders", value: "\(desktop2.folders.count)", state: desktop2.folders.isEmpty ? .warning : .good),
                    StatusItem(title: "Startup", value: launchAtStartup ? "On" : "Off", state: launchAtStartup ? .good : .warning),
                    StatusItem(title: "Last Action", value: lastAction, state: .good)
                ])
            }
        }
        .onAppear {
            desktop2.reloadFolders()
            launchAtStartup = Desktop2Store.launchAtStartup
        }
    }
}

private struct ScreenSettingsDetailView: View {
    @State private var shortcut = ScreenShortcut.current()
    @State private var spaceSwitchingEnabled = SpaceSwitchShortcutStore.isEnabled
    @State private var controlArrowSnapEnabled = ControlArrowSnapStore.isEnabled
    @State private var optionUpSnapAliasEnabled = UpSnapAliasStore.optionUpEnabled
    @State private var commandUpSnapAliasEnabled = UpSnapAliasStore.commandUpEnabled
    @State private var browserTabSnapEnabled = BrowserTabSnapStore.isEnabled
    @State private var browserTabQuickPairEnabled = BrowserTabSnapStore.quickOppositeArrowEnabled
    @State private var browserMonitorMoveChoiceEnabled = BrowserMonitorMoveStore.isEnabled
    @State private var monitorMoveShortcutEnabled = MonitorMoveShortcutStore.isEnabled
    @State private var monitorMoveOthersShortcutEnabled = MonitorMoveOthersShortcutStore.isEnabled
    @State private var desktopIconsShortcutEnabled = DesktopIconsShortcutStore.isEnabled
    @State private var commandHideToggleEnabled = CommandHideToggleStore.isEnabled
    @State private var commandHideFocusedWindowOnly = CommandHideToggleStore.hidesFocusedWindowOnly
    @State private var commandShiftHideMonitorEnabled = CommandShiftHideMonitorStore.isEnabled
    @State private var focusedDisplayMissionControlEnabled = DisplaySpacesStore.missionControlFocusedDisplayOnly
    @State private var hoverFocusEnabled = HoverFocusStore.isEnabled
    @State private var autoScrollEnabled = AutoScrollStore.isEnabled
    @State private var fullscreenEscapeEnabled = FullscreenEscapeStore.isEnabled
    @State private var cursorJumpEnabled = CursorJumpStore.isEnabled
    @State private var cursorJumpShortcut = CursorJumpStore.currentShortcut()
    @State private var displayCount = NSScreen.screens.count

    var body: some View {
        SettingsPage(title: "Screen", subtitle: "") {
            SettingsSectionBlock(
                title: "Move Between Monitors",
                subtitle: ""
            ) {
                SettingsGroup {
                    ShortcutRecorderRow(shortcut: $shortcut)

                    Divider()

                    SettingsInfoRow(
                        title: "Move active app between monitors",
                        subtitle: "Press \(shortcut.displayText). The shortcut is always active while this app is running.",
                        value: displayCount > 1 ? "\(displayCount) displays" : "One display"
                    )

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Ask tab or window for browsers",
                        subtitle: "Optional step: when Chrome, Safari, or Edge is focused and you press \(shortcut.displayText), choose T to move only the active tab or W to move the whole window."
                    ) {
                        Toggle("", isOn: $browserMonitorMoveChoiceEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: browserMonitorMoveChoiceEnabled) { _, newValue in
                                BrowserMonitorMoveStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Window Sizing",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Control-Arrow window sizing",
                        subtitle: "Control-Arrows use mouse position, not clicks: the window under the pointer is resized; if no window is there, the topmost window on that monitor is used. YouTube videos switch to theater mode after left/right snaps."
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
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Option-Up also fills the screen",
                        subtitle: "Speed alias for Control-Up: Up is rarely used in shortcuts, so your hand can hit an easy Up chord instantly instead of spending slower reasoning-model brain time choosing the perfect key."
                    ) {
                        Toggle("", isOn: $optionUpSnapAliasEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: optionUpSnapAliasEnabled) { _, newValue in
                                UpSnapAliasStore.setOptionUpEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Command-Up also fills the screen",
                        subtitle: "Another speed alias for Control-Up, so full-window snap stays in instant brain-computation mode."
                    ) {
                        Toggle("", isOn: $commandUpSnapAliasEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: commandUpSnapAliasEnabled) { _, newValue in
                                UpSnapAliasStore.setCommandUpEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Command-Option-Arrow snaps tab or app",
                        subtitle: "In Chrome, Safari, or Edge, it moves the active tab into its own snapped window. In other apps, it snaps the focused window left or right; press Left-Right-Right quickly to split three recent apps into thirds."
                    ) {
                        Toggle("", isOn: $browserTabSnapEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: browserTabSnapEnabled) { _, newValue in
                                BrowserTabSnapStore.setEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsToggleRow(
                        title: "Quick opposite arrow snaps next tab",
                        subtitle: "Optional step: press Command-Option-Left then Command-Option-Right quickly, or the reverse, and the first tab snaps one side while the next tab from the original browser window snaps the other side."
                    ) {
                        Toggle("", isOn: $browserTabQuickPairEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(!browserTabSnapEnabled)
                            .onChange(of: browserTabQuickPairEnabled) { _, newValue in
                                BrowserTabSnapStore.setQuickOppositeArrowEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Move all windows on current monitor",
                        subtitle: "Control-Option-Command plus arrows arranges recent apps. One arrow places the top app left or right; more arrows add more recent windows."
                    ) {
                        Toggle("", isOn: $monitorMoveShortcutEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: monitorMoveShortcutEnabled) { _, newValue in
                                MonitorMoveShortcutStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Move other windows on current monitor",
                        subtitle: "Control-Option-Command-Space opens the monitor chooser. Press an arrow after Space to switch it to all apps except the focused one."
                    ) {
                        Toggle("", isOn: $monitorMoveOthersShortcutEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: monitorMoveOthersShortcutEnabled) { _, newValue in
                                MonitorMoveOthersShortcutStore.setEnabled(newValue)
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
                title: "Focus",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Focus window on hover",
                        subtitle: "Move your mouse over a window for a moment to focus and raise it without clicking. It does not place the text cursor inside fields."
                    ) {
                        Toggle("", isOn: $hoverFocusEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: hoverFocusEnabled) { _, newValue in
                                HoverFocusStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "No click behavior",
                        subtitle: "This avoids play/pause buttons and links; apps that require a click for caret placement still need one click.",
                        value: hoverFocusEnabled ? "On" : "Off"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Cursor Jump",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Jump cursor to screen points",
                        subtitle: "Press \(CursorJumpStore.shortcutText). With two monitors, it skips monitor choice and opens the point pad for the other monitor. With three or more, pick the monitor first."
                    ) {
                        Toggle("", isOn: $cursorJumpEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: cursorJumpEnabled) { _, newValue in
                                CursorJumpStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    ShortcutRecorderRow(
                        title: "Shortcut",
                        idleSubtitle: "Click the keys to record your own shortcut.",
                        recordingSubtitle: "Press any shortcut up to four keys. You do not need to fill all four.",
                        shortcut: $cursorJumpShortcut
                    ) { newShortcut in
                        CursorJumpStore.saveShortcut(newShortcut)
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Point map",
                        subtitle: "1/2/3 are top, 4/5/6 are middle, and 7/8/9 are bottom. 5 and 0 both jump to center.",
                        value: cursorJumpEnabled ? "On" : "Off"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Fullscreen Escape",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Command-Option-Tab switches fullscreen windows",
                        subtitle: "Use this when a real macOS fullscreen window feels trapped in its own Space. Option-Tab stays for the window switcher; this shortcut is only for fullscreen windows."
                    ) {
                        Toggle("", isOn: $fullscreenEscapeEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: fullscreenEscapeEnabled) { _, newValue in
                                FullscreenEscapeStore.setEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsInfoRow(
                        title: "Shortcut",
                        subtitle: "Cycles through fullscreen windows that Accessibility can see, then raises the chosen window.",
                        value: "Command-Option-Tab"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Autoscroll",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Control-Option-Command-A autoscroll",
                        subtitle: "Open a small chooser for Up or Down autoscroll with Slow, Medium, and Fast speeds. Press the shortcut again to stop."
                    ) {
                        Toggle("", isOn: $autoScrollEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: autoScrollEnabled) { _, newValue in
                                AutoScrollStore.setEnabled(newValue)
                            }
                    }

                    Divider()
                        .padding(.leading, 10)

                    SettingsInfoRow(
                        title: "Browser-style page scrolling",
                        subtitle: "Works on the page under your pointer or focused scroll area. Trackpad double-three-finger tap is not exposed by macOS.",
                        value: autoScrollEnabled ? "On" : "Off"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Mission Control",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Mission Control only on focused display",
                        subtitle: focusedDisplayMissionControlEnabled
                            ? "Four-finger swipe up should show Mission Control for the active display only. Log out or restart once if it does not change immediately."
                            : "Four-finger swipe up can span displays. Turn this on to make each display keep its own Mission Control view."
                    ) {
                        Toggle("", isOn: $focusedDisplayMissionControlEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: focusedDisplayMissionControlEnabled) { _, newValue in
                                focusedDisplayMissionControlEnabled = DisplaySpacesStore.setMissionControlFocusedDisplayOnly(newValue)
                            }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Applies after logout",
                        subtitle: "macOS may require a logout or restart before this Mission Control behavior fully updates.",
                        value: focusedDisplayMissionControlEnabled ? "On" : "Off"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Desktop Icons",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Command-Shift-X toggles desktop icons",
                        subtitle: "Press Command-Shift-X to hide all desktop icons. Press it again to show them."
                    ) {
                        Toggle("", isOn: $desktopIconsShortcutEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: desktopIconsShortcutEnabled) { _, newValue in
                                DesktopIconsShortcutStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Hide Apps",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Command-H hides then restores one app",
                        subtitle: "Press Command-H to hide the focused app. Press Command-H again from another app to bring only that hidden app back."
                    ) {
                        Toggle("", isOn: $commandHideToggleEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: commandHideToggleEnabled) { _, newValue in
                                CommandHideToggleStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Command-H hides focused window only",
                        subtitle: "Optional step: minimize only the window you are on instead of hiding every window from that app. Better for Chrome, Zoom, and multi-monitor work."
                    ) {
                        Toggle("", isOn: $commandHideFocusedWindowOnly)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: commandHideFocusedWindowOnly) { _, newValue in
                                CommandHideToggleStore.setHidesFocusedWindowOnly(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Command-Shift-H hides this monitor",
                        subtitle: "Press Command-Shift-H to hide every visible app on the current monitor except the focused app."
                    ) {
                        Toggle("", isOn: $commandShiftHideMonitorEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: commandShiftHideMonitorEnabled) { _, newValue in
                                CommandShiftHideMonitorStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Move Shortcut", value: shortcut.displayText, state: .good),
                    StatusItem(title: "Sizing", value: controlArrowSnapEnabled ? "On" : "Off", state: controlArrowSnapEnabled ? .good : .warning),
                    StatusItem(title: "Up Aliases", value: upAliasStatusText, state: (optionUpSnapAliasEnabled || commandUpSnapAliasEnabled) ? .good : .warning),
                    StatusItem(title: "Tab Snap", value: browserTabSnapEnabled ? "On" : "Off", state: browserTabSnapEnabled ? .good : .warning),
                    StatusItem(title: "Monitor Move", value: monitorMoveShortcutEnabled ? "On" : "Off", state: monitorMoveShortcutEnabled ? .good : .warning),
                    StatusItem(title: "Move Others", value: monitorMoveOthersShortcutEnabled ? "On" : "Off", state: monitorMoveOthersShortcutEnabled ? .good : .warning),
                    StatusItem(title: "Hover Focus", value: hoverFocusEnabled ? "On" : "Off", state: hoverFocusEnabled ? .good : .warning),
                    StatusItem(title: "Cursor Jump", value: cursorJumpEnabled ? "On" : "Off", state: cursorJumpEnabled ? .good : .warning),
                    StatusItem(title: "Fullscreen Escape", value: fullscreenEscapeEnabled ? "On" : "Off", state: fullscreenEscapeEnabled ? .good : .warning),
                    StatusItem(title: "Autoscroll", value: autoScrollEnabled ? "On" : "Off", state: autoScrollEnabled ? .good : .warning),
                    StatusItem(title: "Desktop Icons", value: desktopIconsShortcutEnabled ? "On" : "Off", state: desktopIconsShortcutEnabled ? .good : .warning),
                    StatusItem(title: "Command-H", value: commandHideToggleEnabled ? (commandHideFocusedWindowOnly ? "Window" : "App") : "System", state: commandHideToggleEnabled ? .good : .warning),
                    StatusItem(title: "Command-Shift-H", value: commandShiftHideMonitorEnabled ? "Monitor" : "Off", state: commandShiftHideMonitorEnabled ? .good : .warning),
                    StatusItem(title: "Spaces Shortcut", value: spaceSwitchingEnabled ? "On" : "Off", state: spaceSwitchingEnabled ? .warning : .good),
                    StatusItem(title: "Mission Control", value: focusedDisplayMissionControlEnabled ? "Per Display" : "Spans", state: focusedDisplayMissionControlEnabled ? .good : .warning)
                ])
            }
        }
        .onAppear {
            shortcut = ScreenShortcut.current()
            spaceSwitchingEnabled = SpaceSwitchShortcutStore.isEnabled
            controlArrowSnapEnabled = ControlArrowSnapStore.isEnabled
            optionUpSnapAliasEnabled = UpSnapAliasStore.optionUpEnabled
            commandUpSnapAliasEnabled = UpSnapAliasStore.commandUpEnabled
            browserTabSnapEnabled = BrowserTabSnapStore.isEnabled
            browserTabQuickPairEnabled = BrowserTabSnapStore.quickOppositeArrowEnabled
            browserMonitorMoveChoiceEnabled = BrowserMonitorMoveStore.isEnabled
            monitorMoveShortcutEnabled = MonitorMoveShortcutStore.isEnabled
            monitorMoveOthersShortcutEnabled = MonitorMoveOthersShortcutStore.isEnabled
            desktopIconsShortcutEnabled = DesktopIconsShortcutStore.isEnabled
            commandHideToggleEnabled = CommandHideToggleStore.isEnabled
            commandHideFocusedWindowOnly = CommandHideToggleStore.hidesFocusedWindowOnly
            commandShiftHideMonitorEnabled = CommandShiftHideMonitorStore.isEnabled
            focusedDisplayMissionControlEnabled = DisplaySpacesStore.missionControlFocusedDisplayOnly
            hoverFocusEnabled = HoverFocusStore.isEnabled
            autoScrollEnabled = AutoScrollStore.isEnabled
            fullscreenEscapeEnabled = FullscreenEscapeStore.isEnabled
            cursorJumpEnabled = CursorJumpStore.isEnabled
            cursorJumpShortcut = CursorJumpStore.currentShortcut()
            displayCount = NSScreen.screens.count
        }
    }

    private var upAliasStatusText: String {
        switch (optionUpSnapAliasEnabled, commandUpSnapAliasEnabled) {
        case (true, true): return "Option + Command"
        case (true, false): return "Option"
        case (false, true): return "Command"
        case (false, false): return "Off"
        }
    }
}

private struct WindowSwitcherSettingsDetailView: View {
    @State private var enabled = WindowSwitcherSettingsStore.enabled
    @State private var showThumbnails = WindowSwitcherSettingsStore.showThumbnails
    @State private var includeMinimized = WindowSwitcherSettingsStore.includeMinimized
    @State private var currentMonitorFirst = WindowSwitcherSettingsStore.currentMonitorFirst
    @State private var moveCursorToSelectedMonitor = WindowSwitcherSettingsStore.moveCursorToSelectedMonitor
    @State private var excludeFinder = WindowSwitcherSettingsStore.excludeFinder
    @State private var excludeHiddenApps = WindowSwitcherSettingsStore.excludeHiddenApps
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var keyboardSafetyStatus = "Ready"

    var body: some View {
        SettingsPage(title: "Window Switcher", subtitle: "") {
            SettingsSectionBlock(
                title: "Option-Tab",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Enable Option-Tab window switcher",
                        subtitle: "Option-Tab cycles every visible window. Option-Shift-Tab cycles backward. Option-` cycles only the focused app."
                    ) {
                        Toggle("", isOn: $enabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: enabled) { _, newValue in
                                WindowSwitcherSettingsStore.setEnabled(newValue)
                            }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Selection",
                        subtitle: "Release Option to focus the selected window and raise it to the front.",
                        value: "Release Option"
                    )
                }
            }

            if !accessibilityTrusted {
                SettingsSectionBlock(
                    title: "Permission Needed",
                    subtitle: ""
                ) {
                    SettingsGroup {
                        SettingsActionRow(
                            title: "Accessibility access",
                            subtitle: "Required to read window titles and focus the selected window. The switcher will not run until this is allowed.",
                            value: "Needs access",
                            buttonTitle: "Open"
                        ) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Modifier Key Safety",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsWarningRow(
                        title: "Beware of stuck modifier keys",
                        subtitle: "If Option, Control, Shift, Command, or Fn ever feels stuck after using the switcher, press Reset. Avoid holding Option after the overlay closes; if typing or clicking starts firing weird shortcuts, reset here first."
                    )

                    Divider()

                    SettingsActionRow(
                        title: "Reset stuck keys",
                        subtitle: "Releases modifier keys at the system level without changing your Window Switcher settings.",
                        value: keyboardSafetyStatus,
                        buttonTitle: "Reset"
                    ) {
                        ModifierKeySafety.releaseShortcutModifiers()
                        keyboardSafetyStatus = "Reset sent"
                    }
                }
            }

            SettingsSectionBlock(
                title: "Overlay",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Show thumbnails when available",
                        subtitle: "Version one shows clean cards with app icon and title. This leaves room for previews later."
                    ) {
                        Toggle("", isOn: $showThumbnails)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: showThumbnails) { _, newValue in
                                WindowSwitcherSettingsStore.setShowThumbnails(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Current monitor first",
                        subtitle: "After the current app, prefer windows on the monitor where your pointer is."
                    ) {
                        Toggle("", isOn: $currentMonitorFirst)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: currentMonitorFirst) { _, newValue in
                                WindowSwitcherSettingsStore.setCurrentMonitorFirst(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Move cursor to selected window’s monitor",
                        subtitle: "When switching to a window on another display, optionally move the pointer toward that window too."
                    ) {
                        Toggle("", isOn: $moveCursorToSelectedMonitor)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: moveCursorToSelectedMonitor) { _, newValue in
                                WindowSwitcherSettingsStore.setMoveCursorToSelectedMonitor(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Window List",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Include minimized windows",
                        subtitle: "Off by default so the switcher only cycles windows that are already visible."
                    ) {
                        Toggle("", isOn: $includeMinimized)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: includeMinimized) { _, newValue in
                                WindowSwitcherSettingsStore.setIncludeMinimized(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Exclude Finder from switcher",
                        subtitle: "Hide Finder windows from Option-Tab if Finder gets in your way."
                    ) {
                        Toggle("", isOn: $excludeFinder)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: excludeFinder) { _, newValue in
                                WindowSwitcherSettingsStore.setExcludeFinder(newValue)
                            }
                    }

                    Divider()

                    SettingsToggleRow(
                        title: "Exclude hidden apps",
                        subtitle: "Skip windows from apps hidden with Command-H."
                    ) {
                        Toggle("", isOn: $excludeHiddenApps)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: excludeHiddenApps) { _, newValue in
                                WindowSwitcherSettingsStore.setExcludeHiddenApps(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Current State",
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Switcher", value: enabled ? "On" : "Off", state: enabled ? .good : .warning),
                    StatusItem(title: "Accessibility", value: accessibilityTrusted ? "Allowed" : "Off", state: accessibilityTrusted ? .good : .warning),
                    StatusItem(title: "Thumbnails", value: showThumbnails ? "Prepared" : "Cards", state: .good),
                    StatusItem(title: "Minimized", value: includeMinimized ? "Included" : "Hidden", state: includeMinimized ? .warning : .good)
                ])
            }
        }
        .onAppear {
            refresh()
        }
    }

    private func refresh() {
        WindowSwitcherSettingsStore.seedDefaultsIfNeeded()
        enabled = WindowSwitcherSettingsStore.enabled
        showThumbnails = WindowSwitcherSettingsStore.showThumbnails
        includeMinimized = WindowSwitcherSettingsStore.includeMinimized
        currentMonitorFirst = WindowSwitcherSettingsStore.currentMonitorFirst
        moveCursorToSelectedMonitor = WindowSwitcherSettingsStore.moveCursorToSelectedMonitor
        excludeFinder = WindowSwitcherSettingsStore.excludeFinder
        excludeHiddenApps = WindowSwitcherSettingsStore.excludeHiddenApps
        accessibilityTrusted = AXIsProcessTrusted()
    }
}

private struct MicSettingsDetailView: View {
    @State private var devices = AudioInputStore.inputDevices()
    @State private var defaultDevice = AudioInputStore.defaultInputDevice()
    @State private var bluetoothPromptsEnabled = BluetoothAudioInputPromptStore.isEnabled
    @State private var networkWarningEnabled = MicNetworkWarningStore.isEnabled
    @State private var activeMicNames = AudioInputStore.activeInputDeviceNames()
    @State private var lastResult = "Ready"
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        SettingsPage(title: "Mic", subtitle: "Keep your system input clean when Bluetooth headphones connect or speech starts offline.") {
            SettingsSectionBlock(
                title: "Bluetooth Audio Prompt",
                subtitle: "Useful for AirPods and headphones that crush input quality when macOS chooses their mic."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Ask when Bluetooth audio connects",
                        subtitle: "When a new Bluetooth audio input appears, show a centered Sound input picker. Non-audio Bluetooth devices do not trigger this."
                    ) {
                        Toggle("", isOn: $bluetoothPromptsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: bluetoothPromptsEnabled) { _, newValue in
                                BluetoothAudioInputPromptStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Speech Wi-Fi Warning",
                subtitle: "Warn immediately when any app starts using the microphone while Wi-Fi is off or disconnected."
            ) {
                SettingsGroup {
                    SettingsToggleRow(
                        title: "Warn when mic starts offline",
                        subtitle: "Works at the Mac audio-device level, so it can catch Codex, ChatGPT, WhatsApp, browser voice search, and dictation-style apps when they activate a microphone."
                    ) {
                        Toggle("", isOn: $networkWarningEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: networkWarningEnabled) { _, newValue in
                                MicNetworkWarningStore.setEnabled(newValue)
                            }
                    }
                }
            }

            SettingsSectionBlock(
                title: "Input Device",
                subtitle: ""
            ) {
                SettingsGroup {
                    ForEach(devices) { device in
                        SettingsActionRow(
                            title: device.name,
                            subtitle: device.id == defaultDevice?.id ? "Current default input." : "\(device.transport.label) microphone.",
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
                subtitle: ""
            ) {
                StatusGrid(items: [
                    StatusItem(title: "Default Mic", value: defaultDevice?.name ?? "None", state: defaultDevice == nil ? .warning : .good),
                    StatusItem(title: "Inputs", value: "\(devices.count)", state: devices.isEmpty ? .warning : .good),
                    StatusItem(title: "Bluetooth Prompt", value: bluetoothPromptsEnabled ? "On" : "Off", state: bluetoothPromptsEnabled ? .good : .warning),
                    StatusItem(title: "Wi-Fi Warning", value: networkWarningEnabled ? "On" : "Off", state: networkWarningEnabled ? .good : .warning),
                    StatusItem(title: "Mic Active", value: activeMicNames.isEmpty ? "No" : "Yes", state: activeMicNames.isEmpty ? .warning : .good),
                    StatusItem(title: "Last Action", value: lastResult, state: .good)
                ])
            }
        }
        .onAppear {
            refreshDevices()
        }
        .onReceive(timer) { _ in
            refreshDevices()
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

    private func refreshDevices() {
        devices = AudioInputStore.inputDevices()
        defaultDevice = AudioInputStore.defaultInputDevice()
        bluetoothPromptsEnabled = BluetoothAudioInputPromptStore.isEnabled
        networkWarningEnabled = MicNetworkWarningStore.isEnabled
        activeMicNames = AudioInputStore.activeInputDeviceNames()
    }
}

private struct ModesSettingsDetailView: View {
    @State private var selectedModeName: LayoutPresetName = .coding
    @State private var modes = WindowLayoutStore.loadModes()
    @State private var lastResult = "Ready"

    private var selectedMode: WindowMode {
        modes.first { $0.name == selectedModeName } ?? WindowMode(name: selectedModeName, rules: WindowLayoutStore.defaultRules(for: selectedModeName))
    }

    var body: some View {
        SettingsPage(title: "Modes", subtitle: "") {
            SettingsSectionBlock(
                title: "Choose Mode",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsPickerRow(title: "Mode", subtitle: "Pick a saved mode to edit.", value: $selectedModeName) {
                        ForEach(LayoutPresetName.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }

                    Divider()

                    SettingsInfoRow(
                        title: "Mode chooser shortcut",
                        subtitle: "Press this once, choose a mode in the centered overlay, and the apps open into place.",
                        value: WindowLayoutStore.modeShortcutText
                    )

                    Divider()

                    SettingsInfoRow(
                        title: "Menu bar mode launcher",
                        subtitle: "Right-click the Mac Sys Settings 2 menu bar icon, choose a mode, and it applies to the display under your mouse.",
                        value: "On"
                    )
                }
            }

            SettingsSectionBlock(
                title: "Apps and Alignment",
                subtitle: ""
            ) {
                SettingsGroup {
                    ForEach(selectedMode.rules) { rule in
                        if let binding = binding(for: rule) {
                            ModeRuleEditor(rule: binding) {
                                removeRule(rule)
                            }
                        }

                        if rule.id != selectedMode.rules.last?.id {
                            Divider()
                        }
                    }

                    Divider()

                    SettingsActionRow(
                        title: "Add app",
                        subtitle: "Adds another picker row using the next available app.",
                        value: "\(selectedMode.rules.count) apps",
                        buttonTitle: "Add"
                    ) {
                        addRule()
                    }
                }
            }

            SettingsSectionBlock(
                title: "Focus Mode",
                subtitle: ""
            ) {
                SettingsGroup {
                    SettingsActionRow(
                        title: "Turn on \(selectedMode.name.rawValue)",
                        subtitle: "Open missing apps, then move and resize them on their saved monitors.",
                        value: lastResult,
                        buttonTitle: "Start"
                    ) {
                        let mode = selectedMode
                        lastResult = "Opening"
                        Task {
                            let results = await WindowLayoutStore.activate(mode)
                            lastResult = results.contains { result in
                                result.contains("required")
                                    || result.contains("not found")
                                    || result.contains("not running")
                                    || result.contains("no window")
                            } ? "Needs attention" : "Applied"
                        }
                    }
                }
            }
        }
        .onAppear {
            modes = WindowLayoutStore.loadModes()
        }
        .onChange(of: selectedModeName) { _, _ in
            lastResult = "Ready"
        }
    }

    private func binding(for rule: WindowLayoutRule) -> Binding<WindowLayoutRule>? {
        guard let modeIndex = modes.firstIndex(where: { $0.name == selectedModeName }),
              let ruleIndex = modes[modeIndex].rules.firstIndex(where: { $0.id == rule.id }) else {
            return nil
        }

        return Binding(
            get: { modes[modeIndex].rules[ruleIndex] },
            set: { updatedRule in
                modes[modeIndex].rules[ruleIndex] = updatedRule
                WindowLayoutStore.saveModes(modes)
            }
        )
    }

    private func addRule() {
        guard let modeIndex = modes.firstIndex(where: { $0.name == selectedModeName }) else { return }

        let existingApps = Set(modes[modeIndex].rules.map(\.appName))
        let appName = WindowLayoutStore.appChoices.first { !existingApps.contains($0) } ?? WindowLayoutStore.appChoices[0]
        modes[modeIndex].rules.append(WindowLayoutRule(appName: appName, screen: .main, position: .center, size: .half))
        WindowLayoutStore.saveModes(modes)
    }

    private func removeRule(_ rule: WindowLayoutRule) {
        guard let modeIndex = modes.firstIndex(where: { $0.name == selectedModeName }),
              modes[modeIndex].rules.count > 1 else { return }

        modes[modeIndex].rules.removeAll { $0.id == rule.id }
        WindowLayoutStore.saveModes(modes)
    }
}

private struct ModeRuleEditor: View {
    @Binding var rule: WindowLayoutRule
    let onRemove: () -> Void

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

            HStack {
                Spacer()
                Button("Remove", action: onRemove)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
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
            .frame(width: 184)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 44)
    }
}

private struct SettingsTextFieldRow: View {
    let title: String
    let subtitle: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 16) {
            RowText(title: title, subtitle: subtitle)
            Spacer(minLength: 12)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5))
                .frame(width: 214)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(minHeight: 44)
    }
}

private enum SettingsColors {
    static let contentBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(red: 0.935, green: 0.935, blue: 0.93)
    static let sidebarSearch = Color.black.opacity(0.055)
    static let sidebarSelection = Color.black.opacity(0.085)
    static let groupFill = Color.black.opacity(0.035)
    static let separator = Color.black.opacity(0.075)
}

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)

                Spacer()
            }
            .frame(height: 46)
            .frame(width: 458, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    content

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(width: 458, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct SettingsSectionBlock<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 10)

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
                .fill(SettingsColors.groupFill)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
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
                .lineLimit(1)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }
}

private struct SettingsWarningRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 48)
    }
}

private struct RowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11))
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

    var body: some View {
        SettingsGroup {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.state == .good ? Color.accentColor : Color.orange)
                        .frame(width: 7, height: 7)

                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 10)

                    Text(item.value)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)

                if item.id != items.last?.id {
                    Divider()
                        .padding(.leading, 27)
                }
            }
        }
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    let idleSubtitle: String
    let recordingSubtitle: String
    @Binding var shortcut: ScreenShortcut
    let onSave: (ScreenShortcut) -> Void
    @State private var isRecording = false
    @State private var draftParts: [String] = []
    @State private var eventMonitor: Any?

    init(
        title: String = "Move shortcut",
        idleSubtitle: String = "Click the keys to record a new shortcut.",
        recordingSubtitle: String = "Press any shortcut up to four keys. You do not need to fill all four.",
        shortcut: Binding<ScreenShortcut>,
        onSave: @escaping (ScreenShortcut) -> Void = { $0.save() }
    ) {
        self.title = title
        self.idleSubtitle = idleSubtitle
        self.recordingSubtitle = recordingSubtitle
        self._shortcut = shortcut
        self.onSave = onSave
    }

    private var visibleParts: [String] {
        isRecording ? draftParts : shortcut.parts
    }

    private var boxParts: [String] {
        if isRecording {
            return draftParts + [""]
        }
        return visibleParts.isEmpty ? [""] : visibleParts
    }

    var body: some View {
        HStack(spacing: 16) {
            RowText(
                title: title,
                subtitle: isRecording ? recordingSubtitle : idleSubtitle
            )

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Array(boxParts.enumerated()), id: \.offset) { index, part in
                        ShortcutKeyBox(
                            text: part,
                            isActive: isRecording && index == boxParts.count - 1
                        )
                    }
                }
                .padding(2)
                .background(ShortcutCaptureView(isRecording: isRecording) { recordedShortcut in
                    draftParts = recordedShortcut.parts
                    shortcut = recordedShortcut
                    onSave(recordedShortcut)
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
                if event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
                    draftParts = []
                    return nil
                }
                return event
            }

            draftParts = recordedShortcut.parts
            shortcut = recordedShortcut
            onSave(recordedShortcut)
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
