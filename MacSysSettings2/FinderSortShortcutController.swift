//
//  FinderSortShortcutController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/20/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class FinderSortShortcutController: ObservableObject {
    @Published private(set) var lastStatus = "Control-Option-Command-S is ready."

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x46535254), id: 1)
    private let chooserPresenter = FinderSortChooserPresenter()

    func start() {
        observeChanges()
        registerHotKey()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func observeChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: FinderSortShortcutStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadHotKey()
            }
        }
    }

    private func reloadHotKey() {
        unregisterHotKey()
        registerHotKey()
    }

    private func registerHotKey() {
        guard FinderSortShortcutStore.isEnabled, hotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install Finder sort shortcut."
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            lastStatus = "Control-Option-Command-S is ready."
            log("Finder sort shortcut registered")
        } else {
            lastStatus = "Control-Option-Command-S could not register."
            log("Finder sort shortcut failed \(status)")
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func ensureEventHandlerInstalled() -> Bool {
        if eventHandlerRef != nil { return true }

        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      hotKeyID.signature == OSType(0x46535254),
                      hotKeyID.id == 1 else {
                    return noErr
                }

                let controller = Unmanaged<FinderSortShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.showChooser()
                }

                return noErr
            },
            1,
            &eventTypes,
            selfPointer,
            &eventHandlerRef
        )

        if status != noErr {
            log("Finder sort InstallEventHandler failed \(status)")
        }

        return status == noErr
    }

    private func showChooser() {
        chooserPresenter.show { [weak self] choice in
            Task { @MainActor in
                self?.apply(choice)
            }
        }
    }

    private func apply(_ choice: FinderSortChoice) {
        guard AXIsProcessTrusted() else {
            lastStatus = "Allow Accessibility permission to sort Finder folders."
            log("Finder sort blocked by missing Accessibility permission")
            return
        }

        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            lastStatus = "Open a Finder folder first."
            log("Finder sort failed: Finder is not running")
            return
        }

        finder.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }
            if self.pressFinderSortMenu(choice, finderProcessIdentifier: finder.processIdentifier) {
                self.lastStatus = "Finder sorted by \(choice.title)."
                self.log(self.lastStatus)
            } else {
                self.lastStatus = "Could not find Finder's Sort By menu."
                self.log("Finder sort failed: Sort By menu item not found for \(choice.title)")
            }
        }
    }

    private func pressFinderSortMenu(_ choice: FinderSortChoice, finderProcessIdentifier pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBar = attribute(kAXMenuBarAttribute, on: appElement),
              let viewMenuItem = child(titled: "View", in: menuBar) else {
            return false
        }

        AXUIElementPerformAction(viewMenuItem, kAXPressAction as CFString)

        guard let viewMenu = firstChild(of: viewMenuItem) else {
            return false
        }

        guard let sortMenuItem = ["Sort By", "Arrange By"].compactMap({ child(titled: $0, in: viewMenu) }).first else {
            return false
        }

        AXUIElementPerformAction(sortMenuItem, kAXPressAction as CFString)

        guard let sortMenu = firstChild(of: sortMenuItem),
              let targetItem = child(titled: choice.title, in: sortMenu) else {
            return false
        }

        return AXUIElementPerformAction(targetItem, kAXPressAction as CFString) == .success
    }

    private func attribute(_ attribute: String, on element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let element = value,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }

        return (element as! AXUIElement)
    }

    private func firstChild(of element: AXUIElement) -> AXUIElement? {
        children(of: element).first
    }

    private func child(titled title: String, in element: AXUIElement) -> AXUIElement? {
        children(of: element).first { stringAttribute(kAXTitleAttribute, on: $0) == title }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }

        return children
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2 FinderSort: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-finder-sort.log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
