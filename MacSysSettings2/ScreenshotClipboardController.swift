//
//  ScreenshotClipboardController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ScreenshotClipboardController: ObservableObject {
    @Published private(set) var isWatching = false
    @Published private(set) var lastStatus = "Off"
    @Published private(set) var lastCopiedFileName = "None"

    private let screenshotDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    private var knownFileNames = Set<String>()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var observer: NSObjectProtocol?
    private var pendingScanTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    func start() {
        seedKnownScreenshots()
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
        clearTask?.cancel()
        pollingTask?.cancel()
    }

    private func observeSettingChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: ScreenshotClipboardStore.didChangeNotification,
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

        guard ScreenshotClipboardStore.isEnabled else {
            lastStatus = "Off"
            return
        }

        fileDescriptor = open(screenshotDirectory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            isWatching = false
            lastStatus = "Could not watch Desktop"
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
        lastStatus = "Watching Desktop screenshots"
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
                guard let self, !Task.isCancelled, ScreenshotClipboardStore.isEnabled else { continue }
                scanForNewScreenshots()
            }
        }
    }

    private func seedKnownScreenshots() {
        knownFileNames = Set(currentScreenshotFiles().map(\.lastPathComponent))
    }

    private func scheduleScan() {
        pendingScanTask?.cancel()
        pendingScanTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            scanForNewScreenshots()
        }
    }

    private func scanForNewScreenshots() {
        let files = currentScreenshotFiles()
        let latestNames = Set(files.map(\.lastPathComponent))
        let addedNames = latestNames.subtracting(knownFileNames)
        knownFileNames = latestNames

        guard let newestScreenshot = files
            .filter({ addedNames.contains($0.lastPathComponent) })
            .sorted(by: { modificationDate(for: $0) > modificationDate(for: $1) })
            .first else {
            return
        }

        copyScreenshotToClipboard(newestScreenshot)
    }

    private func currentScreenshotFiles() -> [URL] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .contentModificationDateKey, .fileSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: screenshotDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )) ?? []

        return urls.filter { url in
            let name = url.lastPathComponent
            guard !name.hasPrefix("."),
                  !name.hasSuffix(".tmp"),
                  !name.hasSuffix(".download"),
                  isScreenshotName(name),
                  isImageExtension(url.pathExtension) else {
                return false
            }

            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isDirectory != true,
                  values?.isHidden != true,
                  (values?.fileSize ?? 0) > 0 else {
                return false
            }

            return true
        }
    }

    private func isScreenshotName(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.hasPrefix("screenshot ") ||
            lowercased.hasPrefix("screen shot ") ||
            lowercased.hasPrefix("screenshot_") ||
            lowercased.hasPrefix("screen_shot_")
    }

    private func isImageExtension(_ pathExtension: String) -> Bool {
        ["png", "jpg", "jpeg", "heic", "tif", "tiff"].contains(pathExtension.lowercased())
    }

    private func modificationDate(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func copyScreenshotToClipboard(_ url: URL) {
        clearTask?.cancel()

        guard let image = NSImage(contentsOf: url) else {
            lastStatus = "Could not read screenshot"
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects([image]) else {
            lastStatus = "Could not copy screenshot"
            return
        }

        let copiedChangeCount = pasteboard.changeCount
        lastCopiedFileName = url.lastPathComponent
        lastStatus = "Copied latest screenshot"

        guard ScreenshotClipboardStore.autoClearEnabled else { return }

        let minutes = ScreenshotClipboardStore.autoClearMinutes
        clearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }

            let currentPasteboard = NSPasteboard.general
            if currentPasteboard.changeCount == copiedChangeCount {
                currentPasteboard.clearContents()
                self?.lastStatus = "Cleared screenshot clipboard"
            } else {
                self?.lastStatus = "Clipboard changed; left it alone"
            }
        }
    }
}
