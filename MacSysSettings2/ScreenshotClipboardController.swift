//
//  ScreenshotClipboardController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/21/26.
//

import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class ScreenshotClipboardController: ObservableObject {
    @Published private(set) var isWatching = false
    @Published private(set) var lastStatus = "Off"
    @Published private(set) var lastCopiedFileName = "None"

    private let screenshotDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    private let dropPicker = ScreenshotDropPickerPresenter()
    private var knownFileNames = Set<String>()
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var observer: NSObjectProtocol?
    private var pendingScanTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var pendingDropPickerTask: Task<Void, Never>?
    private var lastScreenshotShortcutDate: Date?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    func start() {
        seedKnownScreenshots()
        observeSettingChanges()
        installScreenshotShortcutFallback()
        registerScreenshotShortcutEventTap()
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
        pendingDropPickerTask?.cancel()
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
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

        guard ScreenshotClipboardStore.isEnabled || ScreenshotClipboardStore.dropPickerEnabled else {
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
        startPolling(intervalNanoseconds: 250_000_000)

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

    private func startPolling(intervalNanoseconds: UInt64 = 1_000_000_000) {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard let self, !Task.isCancelled, ScreenshotClipboardStore.isEnabled || ScreenshotClipboardStore.dropPickerEnabled else { continue }
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
            try? await Task.sleep(nanoseconds: 120_000_000)
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

        handleNewScreenshot(newestScreenshot)
    }

    private func installScreenshotShortcutFallback() {
        guard globalKeyMonitor == nil, localKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handlePossibleScreenshotShortcut(event)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handlePossibleScreenshotShortcut(event)
            }
            return event
        }
    }

    private func registerScreenshotShortcutEventTap() {
        guard eventTap == nil else { return }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<ScreenshotClipboardController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            Task { @MainActor in
                controller.handlePossibleScreenshotShortcut(keyCode: keyCode, flags: flags)
            }
            return Unmanaged.passUnretained(event)
        }

        var createdEventTap: CFMachPort?
        for tapLocation in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            if let tap = CGEvent.tapCreate(
                tap: tapLocation,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                callback: callback,
                userInfo: selfPointer
            ) {
                createdEventTap = tap
                break
            }
        }

        guard let createdEventTap else { return }
        eventTap = createdEventTap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdEventTap, 0)
        if let eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: createdEventTap, enable: true)
    }

    private func unregisterScreenshotShortcutEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }

        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
    }

    private func handlePossibleScreenshotShortcut(_ event: NSEvent) {
        guard ScreenshotClipboardStore.dropPickerEnabled else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              flags.contains(.shift),
              !flags.contains(.option),
              !flags.contains(.control),
              event.charactersIgnoringModifiers == "3" else {
            return
        }

        lastStatus = "Saw Command-Shift-3"
        showNewestScreenshotFromShortcut()
    }

    private func handlePossibleScreenshotShortcut(keyCode: UInt32, flags: CGEventFlags) {
        guard ScreenshotClipboardStore.dropPickerEnabled,
              keyCode == UInt32(kVK_ANSI_3),
              flags.contains(.maskCommand),
              flags.contains(.maskShift),
              !flags.contains(.maskAlternate),
              !flags.contains(.maskControl) else {
            return
        }

        lastStatus = "Saw Command-Shift-3"
        showNewestScreenshotFromShortcut()
    }

    private func showNewestScreenshotFromShortcut() {
        let triggerDate = Date()
        lastScreenshotShortcutDate = triggerDate
        dropPicker.showPending(on: activeScreenshotScreen())

        pendingDropPickerTask?.cancel()
        pendingDropPickerTask = Task { @MainActor [weak self] in
            for _ in 0..<18 {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let self, !Task.isCancelled else { return }
                guard let newest = currentScreenshotFiles()
                    .filter({ self.modificationDate(for: $0) >= triggerDate.addingTimeInterval(-0.2) })
                    .sorted(by: { self.modificationDate(for: $0) > self.modificationDate(for: $1) })
                    .first else {
                    continue
                }

                knownFileNames.insert(newest.lastPathComponent)
                lastCopiedFileName = newest.lastPathComponent
                lastStatus = "Screenshot ready to drop"
                dropPicker.attach(fileURL: newest, on: activeScreenshotScreen(), dismissAfter: 1.5)
                return
            }
        }
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

    private func handleNewScreenshot(_ url: URL) {
        if ScreenshotClipboardStore.isEnabled {
            copyScreenshotToClipboard(url)
        } else {
            lastCopiedFileName = url.lastPathComponent
            lastStatus = "Screenshot file fallback"
        }

        showDropPickerSoon(for: url)
    }

    private func showDropPickerSoon(for url: URL) {
        guard ScreenshotClipboardStore.dropPickerEnabled else { return }

        pendingDropPickerTask?.cancel()
        if let lastScreenshotShortcutDate,
           Date().timeIntervalSince(lastScreenshotShortcutDate) < 5.0 {
            dropPicker.attach(fileURL: url, on: screenForScreenshot(url), dismissAfter: 1.5)
            return
        }

        pendingDropPickerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            self.dropPicker.show(fileURL: url, on: self.screenForScreenshot(url), dismissAfter: 1.5)
        }
    }

    private func screenForScreenshot(_ url: URL) -> NSScreen? {
        if let activeScreen = activeScreenshotScreen() {
            return activeScreen
        }

        guard let image = NSImage(contentsOf: url) else {
            return nil
        }

        let imageSize = image.representations.first.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
        return NSScreen.screens.min { lhs, rhs in
            let lhsPixelSize = NSSize(width: lhs.frame.width * lhs.backingScaleFactor, height: lhs.frame.height * lhs.backingScaleFactor)
            let rhsPixelSize = NSSize(width: rhs.frame.width * rhs.backingScaleFactor, height: rhs.frame.height * rhs.backingScaleFactor)
            let lhsDelta = abs(lhsPixelSize.width - imageSize.width) + abs(lhsPixelSize.height - imageSize.height)
            let rhsDelta = abs(rhsPixelSize.width - imageSize.width) + abs(rhsPixelSize.height - imageSize.height)
            return lhsDelta < rhsDelta
        }
    }

    private func activeScreenshotScreen() -> NSScreen? {
        NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
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
