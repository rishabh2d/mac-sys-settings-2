//
//  Desktop2Controller.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Combine
import CoreGraphics
import SwiftUI

struct Desktop2Folder: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
}

enum Desktop2Store {
    private static let launchAtStartupKey = "desktop2.launchAtStartup"

    static var launchAtStartup: Bool {
        UserDefaults.standard.bool(forKey: launchAtStartupKey)
    }

    static func setLaunchAtStartup(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: launchAtStartupKey)
    }

    static var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("Mac Sys Settings 2", isDirectory: true)
            .appendingPathComponent("Desktop 2", isDirectory: true)
    }

    static func ensureRoot() {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    static func loadFolders() -> [Desktop2Folder] {
        ensureRoot()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                if leftDate == rightDate {
                    return left.lastPathComponent.localizedStandardCompare(right.lastPathComponent) == .orderedAscending
                }
                return leftDate < rightDate
            }
            .map { url in
                Desktop2Folder(id: url.path, name: url.lastPathComponent, url: url)
            }
    }

    static func createFolder() -> Desktop2Folder? {
        ensureRoot()
        let existingNames = Set(loadFolders().map(\.name))
        let folderName: String
        if !existingNames.contains("New Folder") {
            folderName = "New Folder"
        } else {
            var index = 2
            while existingNames.contains("New Folder \(index)") {
                index += 1
            }
            folderName = "New Folder \(index)"
        }

        let url = rootURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return Desktop2Folder(id: url.path, name: folderName, url: url)
        } catch {
            return nil
        }
    }
}

@MainActor
final class Desktop2Controller: NSObject, ObservableObject {
    static let shared = Desktop2Controller()

    @Published private(set) var folders: [Desktop2Folder] = Desktop2Store.loadFolders()
    @Published private(set) var isVisible = false

    private var windows: [Desktop2Window] = []

    func startIfNeeded() {
        reloadFolders()
        if folders.isEmpty {
            _ = Desktop2Store.createFolder()
            _ = Desktop2Store.createFolder()
            _ = Desktop2Store.createFolder()
            reloadFolders()
        }

        if Desktop2Store.launchAtStartup {
            show()
        }
    }

    func show() {
        reloadFolders()
        closeWindows()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        windows = screens.map { screen in
            let window = Desktop2Window(screen: screen)
            window.contentView = NSHostingView(rootView: Desktop2LayerView(controller: self, screenName: screen.localizedName))
            window.orderFrontRegardless()
            return window
        }
        isVisible = !windows.isEmpty
    }

    func hide() {
        closeWindows()
        isVisible = false
    }

    func addFolder() {
        _ = Desktop2Store.createFolder()
        reloadFolders()
    }

    func openFolder(_ folder: Desktop2Folder) {
        NSWorkspace.shared.open(folder.url)
        NSWorkspace.shared.activateFileViewerSelecting([folder.url])
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
            .first?
            .activate(options: [.activateAllWindows])
    }

    func reloadFolders() {
        folders = Desktop2Store.loadFolders()
    }

    func confirmQuitFromDesktop() {
        let alert = NSAlert()
        alert.messageText = "Quit Desktop 2?"
        alert.informativeText = "This will hide the Desktop 2 layer and quit Mac Sys Settings 2."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    private func closeWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

final class Desktop2Window: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        isReleasedWhenClosed = false
        title = "Desktop 2"
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "q" {
            Desktop2Controller.shared.confirmQuitFromDesktop()
            return
        }

        super.keyDown(with: event)
    }
}

private struct Desktop2LayerView: View {
    @ObservedObject var controller: Desktop2Controller
    let screenName: String

    private let columns = [
        GridItem(.fixed(96), spacing: 22),
        GridItem(.fixed(96), spacing: 22),
        GridItem(.fixed(96), spacing: 22)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Desktop2Background()

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Text("Desktop 2")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))

                    Text(screenName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.10), in: Capsule())
                }
                .padding(.top, 34)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(controller.folders) { folder in
                        Desktop2FolderTile(folder: folder)
                    }

                    Button {
                        controller.addFolder()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white.opacity(0.88))

                            Text("New Folder")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.90))
                                .frame(width: 92)
                        }
                        .frame(width: 96, height: 96)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct Desktop2Background: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.15, blue: 0.20),
                Color(red: 0.08, green: 0.34, blue: 0.44),
                Color(red: 0.04, green: 0.10, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let centers = [
                        CGPoint(x: size.width * (0.18 + 0.03 * sin(seconds / 8)), y: size.height * 0.20),
                        CGPoint(x: size.width * 0.72, y: size.height * (0.52 + 0.04 * cos(seconds / 10))),
                        CGPoint(x: size.width * (0.40 + 0.02 * cos(seconds / 7)), y: size.height * 0.82)
                    ]

                    for (index, center) in centers.enumerated() {
                        let rect = CGRect(x: center.x - 210, y: center.y - 210, width: 420, height: 420)
                        let color = index == 1 ? Color.cyan.opacity(0.18) : Color.mint.opacity(0.15)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
            .blur(radius: 38)
        }
        .ignoresSafeArea()
    }
}

private struct Desktop2FolderTile: View {
    let folder: Desktop2Folder

    var body: some View {
        Button {
            Desktop2Controller.shared.openFolder(folder)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 0.96, green: 0.73, blue: 0.28), Color(red: 0.82, green: 0.48, blue: 0.14))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 5)

                Text(folder.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.50), radius: 3, y: 1)
                    .frame(width: 92)
            }
            .frame(width: 96, height: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(folder.name)")
    }
}
