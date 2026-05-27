//
//  DownloadsWatcherController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class DownloadsWatcherController: ObservableObject {
    @Published private(set) var isWatching = false
    @Published private(set) var lastStatus = "Ready"

    private let presenter = DownloadsPreviewPresenter()
    private let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    private var knownFileNames = Set<String>()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var observer: NSObjectProtocol?
    private var pendingScanTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    func start() {
        seedKnownFiles()
        observeSettingChanges()
        reloadWatcher()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
    }

    private func observeSettingChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: DownloadsPreviewStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadWatcher()
            }
        }
    }

    private func reloadWatcher() {
        stopWatching()

        guard DownloadsPreviewStore.shouldWatchDownloads else {
            lastStatus = "Off"
            return
        }

        fileDescriptor = open(downloadsURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            isWatching = false
            lastStatus = "Could not watch Downloads"
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .extend, .attrib, .link],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.scheduleScan()
            }
        }

        source.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        self.source = source
        self.fileDescriptor = -1
        source.resume()
        startPolling()

        isWatching = true
        lastStatus = "Watching Downloads"
    }

    private func stopWatching() {
        pendingScanTask?.cancel()
        pendingScanTask = nil
        pollingTask?.cancel()
        pollingTask = nil

        if let source {
            source.cancel()
            self.source = nil
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        isWatching = false
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled, DownloadsPreviewStore.shouldWatchDownloads else { continue }
                scanForNewFiles()
            }
        }
    }

    private func seedKnownFiles() {
        knownFileNames = Set(currentVisibleFiles().map(\.lastPathComponent))
    }

    private func scheduleScan() {
        pendingScanTask?.cancel()
        pendingScanTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            scanForNewFiles()
        }
    }

    private func scanForNewFiles() {
        let files = currentVisibleFiles()
        let latestNames = Set(files.map(\.lastPathComponent))
        let addedNames = latestNames.subtracting(knownFileNames)
        knownFileNames = latestNames

        guard let newestFile = files
            .filter({ addedNames.contains($0.lastPathComponent) })
            .sorted(by: { modificationDate(for: $0) > modificationDate(for: $1) })
            .first else {
            return
        }

        lastStatus = newestFile.lastPathComponent
        let sourceScreen = likelyDownloadSourceScreen()

        if DownloadsPreviewStore.isEnabled {
            presenter.show(fileURL: newestFile, on: sourceScreen)
        }

        if DownloadsPreviewStore.opensFinderOnNewDownload {
            openDownloadsFolderShowingNewestFile(newestFile, on: sourceScreen)
        }
    }

    private func currentVisibleFiles() -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )) ?? []

        return urls.filter { url in
            let name = url.lastPathComponent
            guard !name.hasPrefix("."),
                  !name.hasSuffix(".download"),
                  !name.hasSuffix(".crdownload"),
                  !name.hasSuffix(".tmp") else {
                return false
            }

            let values = try? url.resourceValues(forKeys: keys)
            return values?.isDirectory != true && values?.isHidden != true
        }
    }

    private func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func openDownloadsFolderShowingNewestFile(_ fileURL: URL, on sourceScreen: NSScreen?) {
        let downloadsPath = downloadsURL.path
        let filePath = fileURL.path
        let finderFrame = compactDownloadsFinderFrame(on: sourceScreen)

        Task.detached(priority: .utility) {
            let script = """
            on clampDownloadsWindow(leftEdge, topEdge, rightEdge, bottomEdge)
                tell application "Finder"
                    try
                        set bounds of front Finder window to {leftEdge, topEdge, rightEdge, bottomEdge}
                    end try
                    try
                        set sidebar width of front Finder window to 0
                    end try
                end tell
            end clampDownloadsWindow

            on focusDownloadsWindow()
                tell application "Finder" to activate
                tell application "System Events"
                    set frontmost of process "Finder" to true
                end tell
            end focusDownloadsWindow

            on sortDownloadsNewestFirst()
                tell application "Finder"
                    tell list view options of front Finder window
                        set visible of column id modification date column to true
                        set sort column to column id modification date column
                        set sort direction of column id modification date column to reversed
                    end tell
                end tell
            end sortDownloadsNewestFirst

            on run argv
                set downloadsPath to item 1 of argv
                set filePath to item 2 of argv
                set leftEdge to item 3 of argv as integer
                set topEdge to item 4 of argv as integer
                set rightEdge to item 5 of argv as integer
                set bottomEdge to item 6 of argv as integer

                tell application "Finder"
                    activate
                    set downloadsFolder to POSIX file downloadsPath as alias
                    open downloadsFolder
                    set target of front Finder window to downloadsFolder
                    set downloadsWindow to front Finder window
                    set downloadsWindowID to id of downloadsWindow
                    set toolbar visible of front Finder window to true
                    set statusbar visible of front Finder window to false
                    set pathbar visible of front Finder window to false
                    set current view of front Finder window to list view
                    my clampDownloadsWindow(leftEdge, topEdge, rightEdge, bottomEdge)
                    set newFile to POSIX file filePath as alias
                    delay 0.5
                    my clampDownloadsWindow(leftEdge, topEdge, rightEdge, bottomEdge)
                    my sortDownloadsNewestFirst()
                    delay 0.2
                    my clampDownloadsWindow(leftEdge, topEdge, rightEdge, bottomEdge)
                    my sortDownloadsNewestFirst()
                    reveal newFile
                    select newFile
                    my clampDownloadsWindow(leftEdge, topEdge, rightEdge, bottomEdge)
                    my focusDownloadsWindow()
                end tell
            end run
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [
                "-e",
                script,
                downloadsPath,
                filePath,
                "\(Int(finderFrame.minX.rounded()))",
                "\(Int(finderFrame.minY.rounded()))",
                "\(Int(finderFrame.maxX.rounded()))",
                "\(Int(finderFrame.maxY.rounded()))"
            ]
            let errorPipe = Pipe()
            process.standardError = errorPipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                        try? message.write(
                            to: URL(fileURLWithPath: "/tmp/mss2-downloads-finder-error.log"),
                            atomically: true,
                            encoding: .utf8
                        )
                    }
                }
            } catch {
                try? String(describing: error).write(
                    to: URL(fileURLWithPath: "/tmp/mss2-downloads-finder-error.log"),
                    atomically: true,
                    encoding: .utf8
                )
            }
        }
    }

    private func compactDownloadsFinderFrame(on sourceScreen: NSScreen?) -> NSRect {
        let screen = sourceScreen
            ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            return NSRect(x: 0, y: 0, width: 316, height: 252)
        }

        let size = NSSize(width: 316, height: 252)
        let edgeInset: CGFloat = 34
        let visibleFrame = screen.visibleFrame
        let screenFrame = screen.frame
        let displayBounds: CGRect

        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            displayBounds = CGDisplayBounds(displayID)
        } else {
            displayBounds = screenFrame
        }

        let topInset = max(0, screenFrame.maxY - visibleFrame.maxY)
        let bottomInset = max(0, visibleFrame.minY - screenFrame.minY)
        let safeLeft = visibleFrame.minX
        let safeRight = visibleFrame.maxX
        let safeTop = displayBounds.minY + topInset
        let safeBottom = displayBounds.maxY - bottomInset
        let maxLeft = safeRight - edgeInset - size.width
        let minLeft = safeLeft + edgeInset
        let maxTop = safeBottom - edgeInset - size.height
        let minTop = safeTop + edgeInset

        return NSRect(
            x: min(max(minLeft, maxLeft), maxLeft),
            y: min(max(minTop, maxTop), maxTop),
            width: size.width,
            height: size.height
        )
    }

    private func likelyDownloadSourceScreen() -> NSScreen? {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let screen = focusedWindowScreen(for: frontmostApp),
           isLikelyDownloadSource(frontmostApp) {
            return screen
        }

        for bundleID in ["com.google.Chrome", "com.google.Chrome.canary", "com.microsoft.edgemac", "com.apple.Safari"] {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleID && !$0.isTerminated
            }) else {
                continue
            }

            if let screen = focusedWindowScreen(for: app) {
                return screen
            }
        }

        return NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
    }

    private func isLikelyDownloadSource(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        return [
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "com.microsoft.edgemac",
            "com.apple.Safari"
        ].contains(bundleID)
    }

    private func focusedWindowScreen(for app: NSRunningApplication) -> NSScreen? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value else {
            return nil
        }

        let window = value as! AXUIElement
        guard let frame = accessibilityFrame(for: window) else {
            return nil
        }

        return screen(containingAccessibilityFrame: frame)
    }

    private func accessibilityFrame(for window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue((positionValue as! AXValue), .cgPoint, &position),
              AXValueGetValue((sizeValue as! AXValue), .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func screen(containingAccessibilityFrame frame: CGRect) -> NSScreen? {
        NSScreen.screens
            .map { screen -> (screen: NSScreen, area: CGFloat) in
                let intersection = accessibilityScreenFrame(for: screen).intersection(frame)
                let area = intersection.isNull ? 0 : intersection.width * intersection.height
                return (screen, area)
            }
            .max { $0.area < $1.area }?
            .screen
    }

    private func accessibilityScreenFrame(for screen: NSScreen) -> CGRect {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return screen.frame
        }

        return CGDisplayBounds(displayID)
    }
}
