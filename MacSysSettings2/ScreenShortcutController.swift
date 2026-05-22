//
//  ScreenShortcutController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import AppKit
import Carbon
import Combine
import Foundation

@MainActor
final class ScreenShortcutController: ObservableObject {
    @Published private(set) var lastStatus = "\(ScreenShortcut.current().displayText) is ready."

    private var moveHotKeyRef: EventHotKeyRef?
    private var pairedMoveHotKeyRef: EventHotKeyRef?
    private var leftSnapHotKeyRef: EventHotKeyRef?
    private var rightSnapHotKeyRef: EventHotKeyRef?
    private var upSnapHotKeyRef: EventHotKeyRef?
    private var optionUpSnapHotKeyRef: EventHotKeyRef?
    private var commandUpSnapHotKeyRef: EventHotKeyRef?
    private var browserTabLeftHotKeyRef: EventHotKeyRef?
    private var browserTabRightHotKeyRef: EventHotKeyRef?
    private var downSnapHotKeyRef: EventHotKeyRef?
    private var desktopIconsHotKeyRef: EventHotKeyRef?
    private var commandHideHotKeyRef: EventHotKeyRef?
    private var commandShiftHideHotKeyRef: EventHotKeyRef?
    private var instantMinimizeHotKeyRef: EventHotKeyRef?
    private var modeChooserHotKeyRef: EventHotKeyRef?
    private var controlArrowGlobalMonitor: Any?
    private var controlArrowLocalMonitor: Any?
    private var controlArrowEventTap: CFMachPort?
    private var controlArrowRunLoopSource: CFRunLoopSource?
    private var commandHideEventTap: CFMachPort?
    private var commandHideRunLoopSource: CFRunLoopSource?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature = OSType(0x4D535332)
    private let moveHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 1)
    private let pairedMoveHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 4)
    private let leftSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 2)
    private let rightSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 3)
    private let upSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 8)
    private let downSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 9)
    private let optionUpSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 11)
    private let commandUpSnapHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 12)
    private let browserTabLeftHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 13)
    private let browserTabRightHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 14)
    private let desktopIconsHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 5)
    private let commandHideHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 6)
    private let modeChooserHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 7)
    private let commandShiftHideHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 10)
    private let instantMinimizeHotKeyID = EventHotKeyID(signature: OSType(0x4D535332), id: 15)
    private var shortcut = ScreenShortcut.current()
    private var shortcutObserver: NSObjectProtocol?
    private var controlArrowObserver: NSObjectProtocol?
    private var upSnapAliasObserver: NSObjectProtocol?
    private var browserTabSnapObserver: NSObjectProtocol?
    private var monitorMoveObserver: NSObjectProtocol?
    private var monitorMoveOthersObserver: NSObjectProtocol?
    private var desktopIconsObserver: NSObjectProtocol?
    private var commandHideObserver: NSObjectProtocol?
    private var commandShiftHideObserver: NSObjectProtocol?
    private var instantMinimizeObserver: NSObjectProtocol?
    private var applicationHideObserver: NSObjectProtocol?
    private let monitorMoveOverlayPresenter = MonitorMoveOverlayPresenter()
    private let modeChooserPresenter = ModeChooserPresenter()
    private let browserMoveChoicePresenter = BrowserMoveChoicePresenter()
    private var lastMonitorMoveBatch: MonitorMoveBatch?
    private var moveOthersArmedUntil: Date?
    private var parkedHiddenApp: HiddenApp?
    private var parkedHiddenWindow: HiddenWindow?
    private var monitorHiddenSession: MonitorHiddenSession?
    private var suppressCommandHideObserverUntil = Date.distantPast
    private var downSnapLevels: [String: Int] = [:]
    private var horizontalSnapLevels: [String: Int] = [:]
    private var horizontalSnapFrames: [String: CGRect] = [:]
    private var snapAnimationTokens: [String: Int] = [:]
    private var activeSnapTarget: SnapTarget?
    private var activeSnapTargetUntil = Date.distantPast
    private var browserTabPairCandidate: BrowserTabPairCandidate?

    func start() {
        log("ScreenShortcutController starting")
        requestAccessibilityAccess()
        observeShortcutChanges()
        observeControlArrowChanges()
        observeUpSnapAliasChanges()
        observeBrowserTabSnapChanges()
        observeMonitorMoveChanges()
        observeMonitorMoveOthersChanges()
        observeDesktopIconsChanges()
        observeCommandHideChanges()
        observeInstantMinimizeChanges()
        observeApplicationHideEvents()
        registerHotKey()
        registerControlArrowHotKeys()
        registerDesktopIconsHotKey()
        registerCommandHideShortcut()
        registerModeChooserHotKey()
    }

    deinit {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        if let shortcutObserver {
            NotificationCenter.default.removeObserver(shortcutObserver)
        }
        if let controlArrowObserver {
            NotificationCenter.default.removeObserver(controlArrowObserver)
        }
        if let upSnapAliasObserver {
            NotificationCenter.default.removeObserver(upSnapAliasObserver)
        }
        if let browserTabSnapObserver {
            NotificationCenter.default.removeObserver(browserTabSnapObserver)
        }
        if let monitorMoveObserver {
            NotificationCenter.default.removeObserver(monitorMoveObserver)
        }
        if let monitorMoveOthersObserver {
            NotificationCenter.default.removeObserver(monitorMoveOthersObserver)
        }
        if let desktopIconsObserver {
            NotificationCenter.default.removeObserver(desktopIconsObserver)
        }
        if let commandHideObserver {
            NotificationCenter.default.removeObserver(commandHideObserver)
        }
        if let commandShiftHideObserver {
            NotificationCenter.default.removeObserver(commandShiftHideObserver)
        }
        if let instantMinimizeObserver {
            NotificationCenter.default.removeObserver(instantMinimizeObserver)
        }
        if let applicationHideObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(applicationHideObserver)
        }
        if let moveHotKeyRef {
            UnregisterEventHotKey(moveHotKeyRef)
        }
        if let pairedMoveHotKeyRef {
            UnregisterEventHotKey(pairedMoveHotKeyRef)
        }
        if let leftSnapHotKeyRef {
            UnregisterEventHotKey(leftSnapHotKeyRef)
        }
        if let rightSnapHotKeyRef {
            UnregisterEventHotKey(rightSnapHotKeyRef)
        }
        if let upSnapHotKeyRef {
            UnregisterEventHotKey(upSnapHotKeyRef)
        }
        if let optionUpSnapHotKeyRef {
            UnregisterEventHotKey(optionUpSnapHotKeyRef)
        }
        if let commandUpSnapHotKeyRef {
            UnregisterEventHotKey(commandUpSnapHotKeyRef)
        }
        if let browserTabLeftHotKeyRef {
            UnregisterEventHotKey(browserTabLeftHotKeyRef)
        }
        if let browserTabRightHotKeyRef {
            UnregisterEventHotKey(browserTabRightHotKeyRef)
        }
        if let downSnapHotKeyRef {
            UnregisterEventHotKey(downSnapHotKeyRef)
        }
        if let desktopIconsHotKeyRef {
            UnregisterEventHotKey(desktopIconsHotKeyRef)
        }
        if let commandHideHotKeyRef {
            UnregisterEventHotKey(commandHideHotKeyRef)
        }
        if let commandShiftHideHotKeyRef {
            UnregisterEventHotKey(commandShiftHideHotKeyRef)
        }
        if let instantMinimizeHotKeyRef {
            UnregisterEventHotKey(instantMinimizeHotKeyRef)
        }
        if let modeChooserHotKeyRef {
            UnregisterEventHotKey(modeChooserHotKeyRef)
        }
        if let controlArrowGlobalMonitor {
            NSEvent.removeMonitor(controlArrowGlobalMonitor)
        }
        if let controlArrowLocalMonitor {
            NSEvent.removeMonitor(controlArrowLocalMonitor)
        }
        if let controlArrowEventTap {
            CGEvent.tapEnable(tap: controlArrowEventTap, enable: false)
        }
        ModifierKeySafety.releaseAfterShortcutEnds()
        if let controlArrowRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), controlArrowRunLoopSource, .commonModes)
        }
        if let commandHideEventTap {
            CGEvent.tapEnable(tap: commandHideEventTap, enable: false)
        }
        if let commandHideRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), commandHideRunLoopSource, .commonModes)
        }
    }

    private func requestAccessibilityAccess() {
        if !AXIsProcessTrusted() {
            lastStatus = "Allow Accessibility permission to move windows."
            log("Accessibility permission is not granted")
        } else {
            log("Accessibility permission is granted")
        }
    }

    private func registerHotKey() {
        guard moveHotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install \(shortcut.displayText) handler."
            return
        }

        let registerStatus = registerMoveHotKey(
            keyCode: shortcut.keyCode,
            hotKeyID: moveHotKeyID,
            ref: &moveHotKeyRef
        )

        if registerStatus == noErr {
            lastStatus = "\(shortcut.displayText) is ready."
            log("\(shortcut.displayText) registered")

            if let pairedMoveKeyCode = shortcut.pairedMoveKeyCode {
                let pairedStatus = registerMoveHotKey(
                    keyCode: pairedMoveKeyCode,
                    hotKeyID: pairedMoveHotKeyID,
                    ref: &pairedMoveHotKeyRef
                )

                if pairedStatus == noErr {
                    log("\(shortcut.displayText) paired arrow registered")
                } else {
                    log("paired RegisterEventHotKey failed \(pairedStatus)")
                }
            }
        } else {
            lastStatus = "\(shortcut.displayText) is already used by another app."
            log("RegisterEventHotKey failed \(registerStatus)")
        }
    }

    private func registerMoveHotKey(keyCode: UInt32, hotKeyID: EventHotKeyID, ref: inout EventHotKeyRef?) -> OSStatus {
        RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
    }

    private func unregisterHotKey() {
        if let moveHotKeyRef {
            UnregisterEventHotKey(moveHotKeyRef)
            self.moveHotKeyRef = nil
        }
        if let pairedMoveHotKeyRef {
            UnregisterEventHotKey(pairedMoveHotKeyRef)
            self.pairedMoveHotKeyRef = nil
        }
    }

    private func ensureEventHandlerInstalled() -> Bool {
        guard eventHandlerRef == nil else { return true }

        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.signature == OSType(0x4D535332) else { return noErr }

                let controller = Unmanaged<ScreenShortcutController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    controller.handleHotKey(id: hotKeyID.id)
                }

                return noErr
            },
            1,
            eventTypes,
            selfPointer,
            &eventHandlerRef
        )

        if installStatus != noErr {
            log("InstallEventHandler failed \(installStatus)")
        }

        return installStatus == noErr
    }

    private func handleHotKey(id: UInt32) {
        switch id {
        case moveHotKeyID.id, pairedMoveHotKeyID.id:
            guard !isMonitorMoveShortcutChordActive() else {
                log("ignored move hotkey while Command was held")
                return
            }
            log("\(shortcut.displayText) hotkey pressed")
            moveFrontWindowToNextScreen()
        case leftSnapHotKeyID.id:
            log("Control-Left hotkey pressed")
            snapFrontWindow(to: .left)
        case rightSnapHotKeyID.id:
            log("Control-Right hotkey pressed")
            snapFrontWindow(to: .right)
        case upSnapHotKeyID.id, optionUpSnapHotKeyID.id, commandUpSnapHotKeyID.id:
            log("Up snap hotkey pressed")
            snapFrontWindow(to: .up)
        case browserTabLeftHotKeyID.id:
            log("Command-Option-Left browser tab snap pressed")
            snapActiveBrowserTab(to: .left)
        case browserTabRightHotKeyID.id:
            log("Command-Option-Right browser tab snap pressed")
            snapActiveBrowserTab(to: .right)
        case downSnapHotKeyID.id:
            log("Control-Down hotkey pressed")
            snapFrontWindow(to: .down)
        case desktopIconsHotKeyID.id:
            log("Command-Shift-X desktop icons hotkey pressed")
            toggleDesktopIcons()
        case commandHideHotKeyID.id:
            log("Command-H toggle hotkey pressed")
            toggleCommandHide()
        case commandShiftHideHotKeyID.id:
            log("Command-Shift-H monitor hide hotkey pressed")
            hideAppsOnCurrentMonitorExceptFocused()
        case instantMinimizeHotKeyID.id:
            log("Command-M instant minimize hotkey pressed")
            instantMinimizeFocusedWindow()
        case modeChooserHotKeyID.id:
            log("Mode chooser hotkey pressed")
            showModeChooser()
        default:
            break
        }
    }

    private func registerModeChooserHotKey() {
        guard modeChooserHotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install \(WindowLayoutStore.modeShortcutText) handler."
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
            UInt32(controlKey | optionKey | cmdKey),
            modeChooserHotKeyID,
            GetApplicationEventTarget(),
            0,
            &modeChooserHotKeyRef
        )

        if status == noErr {
            log("\(WindowLayoutStore.modeShortcutText) mode chooser hotkey registered")
        } else {
            log("Mode chooser RegisterEventHotKey failed \(status)")
        }
    }

    private func showModeChooser() {
        modeChooserPresenter.show { [weak self] mode in
            Task { @MainActor in
                self?.lastStatus = "Starting \(mode.name.rawValue)."
                let results = await WindowLayoutStore.activate(mode)
                self?.lastStatus = results.contains { $0.contains("required") || $0.contains("not found") } ? "\(mode.name.rawValue) needs attention." : "\(mode.name.rawValue) applied."
                self?.log("mode \(mode.name.rawValue) results: \(results.joined(separator: ", "))")
            }
        }
    }

    private func observeDesktopIconsChanges() {
        guard desktopIconsObserver == nil else { return }

        desktopIconsObserver = NotificationCenter.default.addObserver(
            forName: DesktopIconsShortcutStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadDesktopIconsHotKey()
            }
        }
    }

    private func reloadDesktopIconsHotKey() {
        unregisterDesktopIconsHotKey()
        registerDesktopIconsHotKey()
    }

    private func registerDesktopIconsHotKey() {
        guard DesktopIconsShortcutStore.isEnabled, desktopIconsHotKeyRef == nil else { return }

        guard ensureEventHandlerInstalled() else {
            lastStatus = "Could not install Command-Shift-X handler."
            return
        }

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_X),
            UInt32(cmdKey | shiftKey),
            desktopIconsHotKeyID,
            GetApplicationEventTarget(),
            0,
            &desktopIconsHotKeyRef
        )

        if status == noErr {
            log("Command-Shift-X desktop icons hotkey registered")
        } else {
            log("Command-Shift-X RegisterEventHotKey failed \(status)")
        }
    }

    private func unregisterDesktopIconsHotKey() {
        if let desktopIconsHotKeyRef {
            UnregisterEventHotKey(desktopIconsHotKeyRef)
            self.desktopIconsHotKeyRef = nil
        }
    }

    private func observeCommandHideChanges() {
        guard commandHideObserver == nil else { return }

        commandHideObserver = NotificationCenter.default.addObserver(
            forName: CommandHideToggleStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadCommandHideEventTap()
            }
        }

        commandShiftHideObserver = NotificationCenter.default.addObserver(
            forName: CommandShiftHideMonitorStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadCommandHideEventTap()
            }
        }
    }

    private func observeInstantMinimizeChanges() {
        guard instantMinimizeObserver == nil else { return }

        instantMinimizeObserver = NotificationCenter.default.addObserver(
            forName: InstantMinimizeStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadCommandHideEventTap()
            }
        }
    }

    private func reloadCommandHideEventTap() {
        unregisterCommandHideShortcut()
        parkedHiddenApp = nil
        registerCommandHideShortcut()
    }

    private func observeApplicationHideEvents() {
        guard applicationHideObserver == nil else { return }

        applicationHideObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            guard let controller = self else { return }

            Task { @MainActor in
                controller.handleApplicationDidHide(app)
            }
        }
    }

    private func registerCommandHideShortcut() {
        guard CommandHideToggleStore.isEnabled || CommandShiftHideMonitorStore.isEnabled || InstantMinimizeStore.isEnabled else { return }

        guard ensureEventHandlerInstalled() else {
            registerCommandHideEventTap()
            return
        }

        if CommandHideToggleStore.isEnabled, commandHideHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_H),
                UInt32(cmdKey),
                commandHideHotKeyID,
                GetApplicationEventTarget(),
                0,
                &commandHideHotKeyRef
            )

            if status == noErr {
                log("Command-H toggle hotkey registered")
            } else {
                log("Command-H toggle RegisterEventHotKey failed \(status)")
            }
        }

        if CommandShiftHideMonitorStore.isEnabled, commandShiftHideHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_H),
                UInt32(cmdKey | shiftKey),
                commandShiftHideHotKeyID,
                GetApplicationEventTarget(),
                0,
                &commandShiftHideHotKeyRef
            )

            if status == noErr {
                log("Command-Shift-H monitor hide hotkey registered")
            } else {
                log("Command-Shift-H RegisterEventHotKey failed \(status)")
            }
        }

        if InstantMinimizeStore.isEnabled, instantMinimizeHotKeyRef == nil {
            let status = RegisterEventHotKey(
                UInt32(kVK_ANSI_M),
                UInt32(cmdKey),
                instantMinimizeHotKeyID,
                GetApplicationEventTarget(),
                0,
                &instantMinimizeHotKeyRef
            )

            if status == noErr {
                log("Command-M instant minimize hotkey registered")
            } else {
                log("Command-M instant minimize RegisterEventHotKey failed \(status)")
            }
        }

        registerCommandHideEventTap()
    }

    private func registerCommandHideEventTap() {
        guard (CommandHideToggleStore.isEnabled || CommandShiftHideMonitorStore.isEnabled || InstantMinimizeStore.isEnabled), commandHideEventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }

            let controller = Unmanaged<ScreenShortcutController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.commandHideEventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            if controller.isCommandShiftHideMonitorEvent(event) {
                Task { @MainActor in
                    controller.log("Command-Shift-H monitor hide event tap pressed")
                    controller.hideAppsOnCurrentMonitorExceptFocused()
                }
                return nil
            }

            if controller.isCommandHideToggleEvent(event) {
                let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
                Task { @MainActor in
                    controller.log("Command-H toggle event tap pressed")
                    controller.toggleCommandHide(targetPID: targetPID)
                }
                return nil
            }

            if controller.isInstantMinimizeEvent(event) {
                Task { @MainActor in
                    controller.log("Command-M instant minimize event tap pressed")
                    controller.instantMinimizeFocusedWindow()
                }
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        var registeredTapLocation: CGEventTapLocation?
        var createdEventTap: CFMachPort?
        for tapLocation in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            if let eventTap = CGEvent.tapCreate(
                tap: tapLocation,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: selfPointer
            ) {
                createdEventTap = eventTap
                registeredTapLocation = tapLocation
                break
            }
        }

        guard let eventTap = createdEventTap else {
            log("Command-H event tap failed")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        commandHideEventTap = eventTap
        commandHideRunLoopSource = source
        let tapLabel = registeredTapLocation == .cghidEventTap ? "HID" : "session"
        log("Command-H \(tapLabel) event tap registered")
    }

    private func unregisterCommandHideEventTap() {
        if let commandHideEventTap {
            CGEvent.tapEnable(tap: commandHideEventTap, enable: false)
            self.commandHideEventTap = nil
        }
        if let commandHideRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), commandHideRunLoopSource, .commonModes)
            self.commandHideRunLoopSource = nil
        }
    }

    private func unregisterCommandHideShortcut() {
        if let commandHideHotKeyRef {
            UnregisterEventHotKey(commandHideHotKeyRef)
            self.commandHideHotKeyRef = nil
        }
        if let commandShiftHideHotKeyRef {
            UnregisterEventHotKey(commandShiftHideHotKeyRef)
            self.commandShiftHideHotKeyRef = nil
        }
        if let instantMinimizeHotKeyRef {
            UnregisterEventHotKey(instantMinimizeHotKeyRef)
            self.instantMinimizeHotKeyRef = nil
        }
        unregisterCommandHideEventTap()
    }

    private func observeShortcutChanges() {
        guard shortcutObserver == nil else { return }

        shortcutObserver = NotificationCenter.default.addObserver(
            forName: ScreenShortcut.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadShortcut()
            }
        }
    }

    private func reloadShortcut() {
        let updatedShortcut = ScreenShortcut.current()
        guard updatedShortcut != shortcut else { return }

        unregisterHotKey()
        shortcut = updatedShortcut
        registerHotKey()
        log("shortcut changed to \(shortcut.displayText)")
    }

    private func observeControlArrowChanges() {
        guard controlArrowObserver == nil else { return }

        controlArrowObserver = NotificationCenter.default.addObserver(
            forName: ControlArrowSnapStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func observeUpSnapAliasChanges() {
        guard upSnapAliasObserver == nil else { return }

        upSnapAliasObserver = NotificationCenter.default.addObserver(
            forName: UpSnapAliasStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func reloadControlArrowHotKeys() {
        unregisterControlArrowHotKeys()
        registerControlArrowHotKeys()
    }

    private func observeBrowserTabSnapChanges() {
        guard browserTabSnapObserver == nil else { return }

        browserTabSnapObserver = NotificationCenter.default.addObserver(
            forName: BrowserTabSnapStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func registerControlArrowHotKeys() {
        guard ControlArrowSnapStore.isEnabled
            || MonitorMoveShortcutStore.isEnabled
            || MonitorMoveOthersShortcutStore.isEnabled
            || BrowserTabSnapStore.isEnabled
            || shortcut.carbonModifiers == UInt32(controlKey | optionKey) else { return }

        if ControlArrowSnapStore.isEnabled, ensureEventHandlerInstalled() {
            let leftStatus = registerControlArrowSnapHotKey(
                keyCode: UInt32(kVK_LeftArrow),
                hotKeyID: leftSnapHotKeyID,
                ref: &leftSnapHotKeyRef
            )
            if leftStatus == noErr {
                log("Control-Left snap hotkey registered")
            } else {
                log("Control-Left snap RegisterEventHotKey failed \(leftStatus)")
            }

            let rightStatus = registerControlArrowSnapHotKey(
                keyCode: UInt32(kVK_RightArrow),
                hotKeyID: rightSnapHotKeyID,
                ref: &rightSnapHotKeyRef
            )
            if rightStatus == noErr {
                log("Control-Right snap hotkey registered")
            } else {
                log("Control-Right snap RegisterEventHotKey failed \(rightStatus)")
            }

            let upStatus = registerControlArrowSnapHotKey(
                keyCode: UInt32(kVK_UpArrow),
                hotKeyID: upSnapHotKeyID,
                ref: &upSnapHotKeyRef
            )
            if upStatus == noErr {
                log("Control-Up snap hotkey registered")
            } else {
                log("Control-Up snap RegisterEventHotKey failed \(upStatus)")
            }

            if UpSnapAliasStore.optionUpEnabled {
                let optionUpStatus = registerSnapHotKey(
                    keyCode: UInt32(kVK_UpArrow),
                    modifiers: UInt32(optionKey),
                    hotKeyID: optionUpSnapHotKeyID,
                    ref: &optionUpSnapHotKeyRef
                )
                if optionUpStatus == noErr {
                    log("Option-Up snap alias registered")
                } else {
                    log("Option-Up snap alias RegisterEventHotKey failed \(optionUpStatus)")
                }
            }

            if UpSnapAliasStore.commandUpEnabled {
                let commandUpStatus = registerSnapHotKey(
                    keyCode: UInt32(kVK_UpArrow),
                    modifiers: UInt32(cmdKey),
                    hotKeyID: commandUpSnapHotKeyID,
                    ref: &commandUpSnapHotKeyRef
                )
                if commandUpStatus == noErr {
                    log("Command-Up snap alias registered")
                } else {
                    log("Command-Up snap alias RegisterEventHotKey failed \(commandUpStatus)")
                }
            }

            let downStatus = registerControlArrowSnapHotKey(
                keyCode: UInt32(kVK_DownArrow),
                hotKeyID: downSnapHotKeyID,
                ref: &downSnapHotKeyRef
            )
            if downStatus == noErr {
                log("Control-Down snap hotkey registered")
            } else {
                log("Control-Down snap RegisterEventHotKey failed \(downStatus)")
            }
        }

        if BrowserTabSnapStore.isEnabled, ensureEventHandlerInstalled() {
            let leftStatus = registerSnapHotKey(
                keyCode: UInt32(kVK_LeftArrow),
                modifiers: UInt32(optionKey | cmdKey),
                hotKeyID: browserTabLeftHotKeyID,
                ref: &browserTabLeftHotKeyRef
            )
            if leftStatus == noErr {
                log("Command-Option-Left browser tab snap registered")
            } else {
                log("Command-Option-Left browser tab snap RegisterEventHotKey failed \(leftStatus)")
            }

            let rightStatus = registerSnapHotKey(
                keyCode: UInt32(kVK_RightArrow),
                modifiers: UInt32(optionKey | cmdKey),
                hotKeyID: browserTabRightHotKeyID,
                ref: &browserTabRightHotKeyRef
            )
            if rightStatus == noErr {
                log("Command-Option-Right browser tab snap registered")
            } else {
                log("Command-Option-Right browser tab snap RegisterEventHotKey failed \(rightStatus)")
            }
        }

        registerControlArrowEventTap()
    }

    private func registerControlArrowSnapHotKey(keyCode: UInt32, hotKeyID: EventHotKeyID, ref: inout EventHotKeyRef?) -> OSStatus {
        registerSnapHotKey(
            keyCode: keyCode,
            modifiers: UInt32(controlKey),
            hotKeyID: hotKeyID,
            ref: &ref
        )
    }

    private func registerSnapHotKey(keyCode: UInt32, modifiers: UInt32, hotKeyID: EventHotKeyID, ref: inout EventHotKeyRef?) -> OSStatus {
        guard ref == nil else { return noErr }

        return RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
    }

    private func observeMonitorMoveChanges() {
        guard monitorMoveObserver == nil else { return }

        monitorMoveObserver = NotificationCenter.default.addObserver(
            forName: MonitorMoveShortcutStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func observeMonitorMoveOthersChanges() {
        guard monitorMoveOthersObserver == nil else { return }

        monitorMoveOthersObserver = NotificationCenter.default.addObserver(
            forName: MonitorMoveOthersShortcutStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadControlArrowHotKeys()
            }
        }
    }

    private func unregisterControlArrowHotKeys() {
        if let leftSnapHotKeyRef {
            UnregisterEventHotKey(leftSnapHotKeyRef)
            self.leftSnapHotKeyRef = nil
        }
        if let rightSnapHotKeyRef {
            UnregisterEventHotKey(rightSnapHotKeyRef)
            self.rightSnapHotKeyRef = nil
        }
        if let upSnapHotKeyRef {
            UnregisterEventHotKey(upSnapHotKeyRef)
            self.upSnapHotKeyRef = nil
        }
        if let optionUpSnapHotKeyRef {
            UnregisterEventHotKey(optionUpSnapHotKeyRef)
            self.optionUpSnapHotKeyRef = nil
        }
        if let commandUpSnapHotKeyRef {
            UnregisterEventHotKey(commandUpSnapHotKeyRef)
            self.commandUpSnapHotKeyRef = nil
        }
        if let browserTabLeftHotKeyRef {
            UnregisterEventHotKey(browserTabLeftHotKeyRef)
            self.browserTabLeftHotKeyRef = nil
        }
        if let browserTabRightHotKeyRef {
            UnregisterEventHotKey(browserTabRightHotKeyRef)
            self.browserTabRightHotKeyRef = nil
        }
        if let downSnapHotKeyRef {
            UnregisterEventHotKey(downSnapHotKeyRef)
            self.downSnapHotKeyRef = nil
        }
        unregisterControlArrowMonitors()
        unregisterControlArrowEventTap()
    }

    private func registerControlArrowEventTap() {
        guard controlArrowEventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }

            let controller = Unmanaged<ScreenShortcutController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.controlArrowEventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

            if controller.isMoveOthersArmEvent(event) {
                Task { @MainActor in
                    controller.armMoveOthersShortcut()
                }
                return nil
            }

            if controller.isBrowserTabSnapArrowEvent(event) {
                Task { @MainActor in
                    if keyCode == Int64(kVK_LeftArrow) {
                        controller.log("Command-Option-Left browser tab event tap pressed")
                        controller.snapActiveBrowserTab(to: .left)
                    } else if keyCode == Int64(kVK_RightArrow) {
                        controller.log("Command-Option-Right browser tab event tap pressed")
                        controller.snapActiveBrowserTab(to: .right)
                    }
                }
                return nil
            }

            if controller.isActiveMonitorMoveArrowEvent(event) {
                Task { @MainActor in
                    controller.log("Control-Option active-window arrow event tap pressed")
                    controller.moveFrontWindowToNextScreen()
                }
                return nil
            }

            if controller.isMonitorMoveArrowEvent(event) {
                Task { @MainActor in
                    if controller.moveOthersIsArmed {
                        controller.log("Control-Option-Command-Space arrow event tap pressed")
                        controller.moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: true)
                    } else {
                        controller.log("Control-Option-Command arrow event tap pressed")
                        controller.moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: false)
                    }
                }
                return nil
            }

            if controller.isControlArrowEvent(event) {
                Task { @MainActor in
                    if keyCode == Int64(kVK_LeftArrow) {
                        controller.log("Control-Left event tap pressed")
                        controller.snapFrontWindow(to: .left)
                    } else if keyCode == Int64(kVK_RightArrow) {
                        controller.log("Control-Right event tap pressed")
                        controller.snapFrontWindow(to: .right)
                    } else if keyCode == Int64(kVK_UpArrow) {
                        controller.log("Control-Up event tap pressed")
                        controller.snapFrontWindow(to: .up)
                    } else if keyCode == Int64(kVK_DownArrow) {
                        controller.log("Control-Down event tap pressed")
                        controller.snapFrontWindow(to: .down)
                    }
                }
                return nil
            }

            if controller.isUpSnapAliasEvent(event) {
                Task { @MainActor in
                    controller.log("Up snap alias event tap pressed")
                    controller.snapFrontWindow(to: .up)
                }
                return nil
            }

            if ScreenShortcutController.isPlainArrowEvent(event) {
                Task { @MainActor in
                    guard controller.moveOthersIsArmed else { return }
                    controller.log("Control-Option-Command-Space arrow event tap pressed")
                    controller.moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: true)
                }
            }

            return Unmanaged.passUnretained(event)
        }

        var registeredTapLocation: CGEventTapLocation?
        var createdEventTap: CFMachPort?
        for tapLocation in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            if let eventTap = CGEvent.tapCreate(
                tap: tapLocation,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: callback,
                userInfo: selfPointer
            ) {
                createdEventTap = eventTap
                registeredTapLocation = tapLocation
                break
            }
        }

        guard let eventTap = createdEventTap else {
            log("Control-Arrow event tap failed")
            registerControlArrowMonitors()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        controlArrowEventTap = eventTap
        controlArrowRunLoopSource = source
        let tapLabel = registeredTapLocation == .cghidEventTap ? "HID" : "session"
        log("Control-Arrow \(tapLabel) event tap registered")
    }

    private func unregisterControlArrowEventTap() {
        if let controlArrowEventTap {
            CGEvent.tapEnable(tap: controlArrowEventTap, enable: false)
            self.controlArrowEventTap = nil
        }
        if let controlArrowRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), controlArrowRunLoopSource, .commonModes)
            self.controlArrowRunLoopSource = nil
        }
    }

    private func registerControlArrowMonitors() {
        guard controlArrowGlobalMonitor == nil, controlArrowLocalMonitor == nil else { return }

        controlArrowGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleControlArrowEvent(event)
            }
        }

        controlArrowLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isControlArrowEvent(event) || Self.isUpSnapAliasEvent(event) || Self.isBrowserTabSnapArrowEvent(event) || Self.isActiveMonitorMoveArrowEvent(event) || Self.isMonitorMoveArrowEvent(event) || Self.isMoveOthersArmEvent(event) {
                Task { @MainActor in
                    self?.handleControlArrowEvent(event)
                }
                return nil
            }

            if Self.isPlainArrowEvent(event) {
                Task { @MainActor in
                    guard let self, self.moveOthersIsArmed else { return }
                    self.handleControlArrowEvent(event)
                }
            }

            return event
        }

        log("Control-Arrow monitor registered")
    }

    private func unregisterControlArrowMonitors() {
        if let controlArrowGlobalMonitor {
            NSEvent.removeMonitor(controlArrowGlobalMonitor)
            self.controlArrowGlobalMonitor = nil
        }
        if let controlArrowLocalMonitor {
            NSEvent.removeMonitor(controlArrowLocalMonitor)
            self.controlArrowLocalMonitor = nil
        }
    }

    private func handleControlArrowEvent(_ event: NSEvent) {
        if Self.isMoveOthersArmEvent(event) {
            armMoveOthersShortcut()
            return
        }

        if Self.isBrowserTabSnapArrowEvent(event) {
            if event.keyCode == UInt16(kVK_LeftArrow) {
                log("Command-Option-Left browser tab event pressed")
                snapActiveBrowserTab(to: .left)
            } else if event.keyCode == UInt16(kVK_RightArrow) {
                log("Command-Option-Right browser tab event pressed")
                snapActiveBrowserTab(to: .right)
            }
            return
        }

        if Self.isActiveMonitorMoveArrowEvent(event) {
            log("Control-Option active-window arrow event pressed")
            moveFrontWindowToNextScreen()
            return
        }

        if isMoveOthersArrowEvent(event) {
            log("Control-Option-Command-Space arrow event pressed")
            moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: true)
            return
        }

        if Self.isMonitorMoveArrowEvent(event) {
            log("Control-Option-Command arrow event pressed")
            moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: false)
            return
        }

        if Self.isUpSnapAliasEvent(event) {
            log("Up snap alias event pressed")
            snapFrontWindow(to: .up)
            return
        }

        guard Self.isControlArrowEvent(event) else { return }

        if event.keyCode == UInt16(kVK_LeftArrow) {
            log("Control-Left event pressed")
            snapFrontWindow(to: .left)
        } else if event.keyCode == UInt16(kVK_RightArrow) {
            log("Control-Right event pressed")
            snapFrontWindow(to: .right)
        } else if event.keyCode == UInt16(kVK_UpArrow) {
            log("Control-Up event pressed")
            snapFrontWindow(to: .up)
        } else if event.keyCode == UInt16(kVK_DownArrow) {
            log("Control-Down event pressed")
            snapFrontWindow(to: .down)
        }
    }

    private static func isControlArrowEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            && !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.shift)
            && Self.isArrowKeyCode(event.keyCode)
    }

    private static func isUpSnapAliasEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == UInt16(kVK_UpArrow), !flags.contains(.control), !flags.contains(.shift) else {
            return false
        }

        let optionOnly = UpSnapAliasStore.optionUpEnabled
            && flags.contains(.option)
            && !flags.contains(.command)

        let commandOnly = UpSnapAliasStore.commandUpEnabled
            && flags.contains(.command)
            && !flags.contains(.option)

        return optionOnly || commandOnly
    }

    private static func isBrowserTabSnapArrowEvent(_ event: NSEvent) -> Bool {
        guard BrowserTabSnapStore.isEnabled else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command)
            && flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.shift)
            && (event.keyCode == UInt16(kVK_LeftArrow) || event.keyCode == UInt16(kVK_RightArrow))
    }

    private static func isMonitorMoveArrowEvent(_ event: NSEvent) -> Bool {
        guard MonitorMoveShortcutStore.isEnabled else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            && flags.contains(.command)
            && flags.contains(.option)
            && !flags.contains(.shift)
            && Self.isArrowKeyCode(event.keyCode)
    }

    private static func isActiveMonitorMoveArrowEvent(_ event: NSEvent) -> Bool {
        let shortcut = ScreenShortcut.current()
        guard shortcut.carbonModifiers == UInt32(controlKey | optionKey) else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            && flags.contains(.option)
            && !flags.contains(.command)
            && !flags.contains(.shift)
            && Self.isArrowKeyCode(event.keyCode)
    }

    private static func isMoveOthersArmEvent(_ event: NSEvent) -> Bool {
        guard MonitorMoveOthersShortcutStore.isEnabled else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control)
            && flags.contains(.command)
            && flags.contains(.option)
            && !flags.contains(.shift)
            && event.keyCode == UInt16(kVK_Space)
    }

    private nonisolated func isControlArrowEvent(_ event: CGEvent) -> Bool {
        guard ControlArrowSnapStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskControl)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && Self.isArrowKeyCode(UInt16(keyCode))
    }

    private nonisolated func isUpSnapAliasEvent(_ event: CGEvent) -> Bool {
        guard ControlArrowSnapStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_UpArrow),
              !flags.contains(.maskControl),
              !flags.contains(.maskShift) else {
            return false
        }

        let optionOnly = UpSnapAliasStore.optionUpEnabled
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand)

        let commandOnly = UpSnapAliasStore.commandUpEnabled
            && flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)

        return optionOnly || commandOnly
    }

    private nonisolated func isBrowserTabSnapArrowEvent(_ event: CGEvent) -> Bool {
        guard BrowserTabSnapStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskCommand)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskShift)
            && (keyCode == Int64(kVK_LeftArrow) || keyCode == Int64(kVK_RightArrow))
    }

    private nonisolated func isMonitorMoveArrowEvent(_ event: CGEvent) -> Bool {
        guard MonitorMoveShortcutStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskControl)
            && flags.contains(.maskCommand)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && Self.isArrowKeyCode(UInt16(keyCode))
    }

    private nonisolated func isActiveMonitorMoveArrowEvent(_ event: CGEvent) -> Bool {
        let currentShortcut = ScreenShortcut.current()
        guard currentShortcut.carbonModifiers == UInt32(controlKey | optionKey) else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskShift)
            && Self.isArrowKeyCode(UInt16(keyCode))
    }

    private nonisolated func isMoveOthersArmEvent(_ event: CGEvent) -> Bool {
        guard MonitorMoveOthersShortcutStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskControl)
            && flags.contains(.maskCommand)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && keyCode == Int64(kVK_Space)
    }

    private nonisolated func isCommandHideToggleEvent(_ event: CGEvent) -> Bool {
        guard CommandHideToggleStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && keyCode == Int64(kVK_ANSI_H)
    }

    private nonisolated func isCommandShiftHideMonitorEvent(_ event: CGEvent) -> Bool {
        guard CommandShiftHideMonitorStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskCommand)
            && flags.contains(.maskShift)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
            && keyCode == Int64(kVK_ANSI_H)
    }

    private nonisolated func isInstantMinimizeEvent(_ event: CGEvent) -> Bool {
        guard InstantMinimizeStore.isEnabled else { return false }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return flags.contains(.maskCommand)
            && !flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && keyCode == Int64(kVK_ANSI_M)
    }

    private nonisolated static func isArrowKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == UInt16(kVK_LeftArrow)
            || keyCode == UInt16(kVK_RightArrow)
            || keyCode == UInt16(kVK_UpArrow)
            || keyCode == UInt16(kVK_DownArrow)
    }

    private func moveFrontWindowToNextScreen(skipBrowserChoice: Bool = false) {
        guard AXIsProcessTrusted() else {
            log("move blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            lastStatus = "No front app found."
            log("no front app found")
            return
        }

        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            moveOwnWindowToNextScreen()
            return
        }

        if !skipBrowserChoice,
           BrowserMonitorMoveStore.isEnabled,
           let definition = browserTabSnapDefinitions.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            if let tabCount = activeBrowserWindowTabCount(for: definition), tabCount <= 1 {
                log("skipped browser tab/window chooser because \(definition.appName) window has \(tabCount) tab")
                moveFrontWindowToNextScreen(skipBrowserChoice: true)
                return
            }

            browserMoveChoicePresenter.show(appName: definition.appName) { [weak self] choice in
                guard let self else { return }
                switch choice {
                case .tab:
                    self.moveActiveBrowserTabToNextScreen(definition)
                case .window:
                    self.moveFrontWindowToNextScreen(skipBrowserChoice: true)
                }
            }
            lastStatus = "Choose T for tab or W for window."
            log("showed browser tab/window monitor move chooser")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else {
            lastStatus = "No focused window found for \(app.localizedName ?? "front app")."
            log("no focused window for \(app.localizedName ?? "front app")")
            return
        }

        guard NSScreen.screens.count > 1 else {
            lastStatus = "Only one screen is connected."
            log("only one screen connected")
            return
        }

        guard let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            lastStatus = "Could not read the front window frame."
            log("could not read window frame")
            return
        }

        let currentFrame = CGRect(origin: position, size: size)
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        let currentScreen = screens.first { $0.frame.intersects(currentFrame) } ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }

        let targetScreen = screens[(currentIndex + 1) % screens.count]
        let newFrame = preservingRelativeFrame(
            currentFrame,
            from: currentScreen,
            to: targetScreen,
            usesAccessibilityCoordinates: true
        )

        setWindow(window, position: newFrame.origin, size: newFrame.size)
        lastStatus = "Moved \(app.localizedName ?? "window") to Screen \((screens.firstIndex(of: targetScreen) ?? 0) + 1)."
        log("moved \(app.localizedName ?? "window") from \(currentFrame) to \(newFrame)")
    }

    private func moveActiveBrowserTabToNextScreen(_ definition: BrowserTabSnapDefinition) {
        let result = runBrowserTabSnapScript(definition)
        guard result.success else {
            lastStatus = result.message
            log("browser monitor tab move failed: \(result.message)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + result.snapDelay) { [weak self] in
            guard let self else { return }
            if let targetWindowID = result.targetWindowID {
                _ = self.focusBrowserWindow(definition, windowID: targetWindowID)
            }
            self.moveFrontWindowToNextScreen(skipBrowserChoice: true)
        }

        lastStatus = "Moving \(definition.appName) tab to the other monitor."
        log("moving browser tab to next screen result \(result.message)")
    }

    private func activeBrowserWindowTabCount(for definition: BrowserTabSnapDefinition) -> Int? {
        let script = definition.usesChromeScripting
            ? """
            tell application "\(definition.appName)"
                if not (exists front window) then return "no-window"
                return (count of tabs of front window) as text
            end tell
            """
            : """
            tell application "Safari"
                if not (exists front window) then return "no-window"
                return (count of tabs of front window) as text
            end tell
            """

        var error: NSDictionary?
        let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue ?? ""
        guard error == nil else {
            log("could not read \(definition.appName) tab count")
            return nil
        }

        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func focusedWindow(for appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
           let window = value {
            return (window as! AXUIElement)
        }

        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement] {
            return windows.first
        }

        return nil
    }

    private func moveOwnWindowToNextScreen() {
        guard NSScreen.screens.count > 1 else {
            lastStatus = "Only one screen is connected."
            log("only one screen connected")
            return
        }

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            lastStatus = "No Mac Sys Settings 2 window found."
            log("no self window found")
            return
        }

        let currentFrame = window.frame
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        let currentScreen = screens.first { $0.frame.intersects(currentFrame) } ?? window.screen ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }

        let targetScreen = screens[(currentIndex + 1) % screens.count]
        let newFrame = preservingRelativeFrame(
            currentFrame,
            from: currentScreen,
            to: targetScreen,
            usesAccessibilityCoordinates: false
        )

        window.setFrame(newFrame, display: true, animate: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lastStatus = "Moved Mac Sys Settings 2 to Screen \((screens.firstIndex(of: targetScreen) ?? 0) + 1)."
        log("moved self from \(currentFrame) to \(newFrame)")
    }

    private func toggleDesktopIcons() {
        let iconsAreVisible = desktopIconsAreVisible()
        let shouldShowIcons = !iconsAreVisible

        guard setDesktopIconsVisible(shouldShowIcons) else {
            lastStatus = "Could not change desktop icons."
            log("desktop icons toggle failed")
            return
        }

        restartFinder()
        lastStatus = shouldShowIcons ? "Desktop icons are visible." : "Desktop icons are hidden."
        log(shouldShowIcons ? "desktop icons shown" : "desktop icons hidden")
    }

    private func desktopIconsAreVisible() -> Bool {
        let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.finder", "CreateDesktop"])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else { return true }
        return output != "0" && output.lowercased() != "false"
    }

    private func setDesktopIconsVisible(_ visible: Bool) -> Bool {
        runCommand(
            "/usr/bin/defaults",
            arguments: ["write", "com.apple.finder", "CreateDesktop", "-bool", visible ? "true" : "false"]
        )
        return desktopIconsAreVisible() == visible
    }

    private func restartFinder() {
        _ = runCommand("/usr/bin/killall", arguments: ["Finder"])
    }

    @discardableResult
    private func runCommand(_ launchPath: String, arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            log("command failed \(launchPath): \(error)")
            return ""
        }
    }

    private func toggleCommandHide(targetPID: pid_t? = nil) {
        if CommandHideToggleStore.hidesFocusedWindowOnly {
            toggleParkedFocusedWindow(targetPID: targetPID)
        } else {
            toggleParkedHiddenApp(targetPID: targetPID)
        }
    }

    private func toggleParkedHiddenApp(targetPID: pid_t? = nil) {
        if unhideParkedAppIfPossible() {
            return
        }

        let targetApp = targetPID.flatMap { pid in
            NSWorkspace.shared.runningApplications.first {
                $0.processIdentifier == pid && !$0.isTerminated
            }
        }

        guard let app = targetApp ?? NSWorkspace.shared.frontmostApplication,
              !app.isTerminated,
              app.activationPolicy == .regular else {
            parkedHiddenApp = nil
            lastStatus = "No app to hide."
            log("Command-H toggle found no frontmost app")
            return
        }

        let hiddenApp = HiddenApp(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName ?? "App"
        )

        if app.hide() {
            parkedHiddenApp = hiddenApp
            lastStatus = "Hidden \(hiddenApp.localizedName). Press Command-H to bring it back."
            log("Command-H toggle hid \(hiddenApp.localizedName)")
        } else {
            parkedHiddenApp = nil
            lastStatus = "Could not hide \(hiddenApp.localizedName)."
            log("Command-H toggle hide failed for \(hiddenApp.localizedName)")
        }
    }

    private func handleApplicationDidHide(_ app: NSRunningApplication) {
        guard CommandHideToggleStore.isEnabled,
              Date() >= suppressCommandHideObserverUntil,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              app.activationPolicy == .regular,
              !app.isTerminated else {
            return
        }

        if let parkedHiddenApp {
            if app.processIdentifier != parkedHiddenApp.processIdentifier {
                bringAppToFront(app)
                log("Command-H toggle undid hide for \(app.localizedName ?? "current app")")
            }
            _ = unhideParkedAppIfPossible()
            return
        }

        parkedHiddenApp = HiddenApp(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName ?? "App"
        )
        lastStatus = "Hidden \(app.localizedName ?? "app"). Press Command-H to bring it back."
        log("Command-H toggle parked \(app.localizedName ?? "app") after hide")
    }

    private func unhideParkedAppIfPossible() -> Bool {
        guard let parkedHiddenApp else { return false }

        guard let app = runningApp(for: parkedHiddenApp) else {
            self.parkedHiddenApp = nil
            log("Command-H toggle parked app was no longer running")
            return false
        }

        bringAppToFront(app)
        self.parkedHiddenApp = nil
        lastStatus = "Restored \(app.localizedName ?? parkedHiddenApp.localizedName)."
        log("Command-H toggle restored \(app.localizedName ?? parkedHiddenApp.localizedName)")
        return true
    }

    private func toggleParkedFocusedWindow(targetPID: pid_t? = nil) {
        if restoreParkedHiddenWindowIfPossible() {
            return
        }

        let targetApp = targetPID.flatMap { pid in
            NSWorkspace.shared.runningApplications.first {
                $0.processIdentifier == pid && !$0.isTerminated
            }
        }

        guard let app = targetApp ?? NSWorkspace.shared.frontmostApplication,
              !app.isTerminated,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            parkedHiddenWindow = nil
            lastStatus = "No focused window to hide."
            log("Command-H focused-window found no frontmost app")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else {
            parkedHiddenWindow = nil
            lastStatus = "No focused window found."
            log("Command-H focused-window found no focused window")
            return
        }

        let title = windowStringAttribute(window, kAXTitleAttribute)
        let frame = windowFrame(window)
        let hiddenWindow = HiddenWindow(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName ?? "App",
            title: title,
            frame: frame
        )

        let status = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        guard status == .success else {
            parkedHiddenWindow = nil
            lastStatus = "Could not hide focused window."
            log("Command-H focused-window minimize failed \(status.rawValue)")
            return
        }

        parkedHiddenWindow = hiddenWindow
        lastStatus = "Hidden focused window. Press Command-H to bring it back."
        log("Command-H focused-window minimized \(hiddenWindow.localizedName) \(hiddenWindow.title)")
    }

    private func instantMinimizeFocusedWindow() {
        guard AXIsProcessTrusted() else {
            requestAccessibilityAccess()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              !app.isTerminated,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            lastStatus = "No focused window to minimize."
            log("Command-M instant minimize found no frontmost app")
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else {
            lastStatus = "No focused window found."
            log("Command-M instant minimize found no focused window")
            return
        }

        let status = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        guard status == .success else {
            lastStatus = "Could not minimize focused window."
            log("Command-M instant minimize failed \(status.rawValue)")
            return
        }

        lastStatus = "Focused window minimized."
        log("Command-M instant minimized \(app.localizedName ?? "App") \(windowStringAttribute(window, kAXTitleAttribute))")
    }

    private func restoreParkedHiddenWindowIfPossible() -> Bool {
        guard let parkedHiddenWindow else { return false }

        guard let app = runningApp(for: parkedHiddenWindow) else {
            self.parkedHiddenWindow = nil
            log("Command-H focused-window app was no longer running")
            return false
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = findWindow(for: parkedHiddenWindow, appElement: appElement) else {
            self.parkedHiddenWindow = nil
            lastStatus = "Could not find hidden window."
            log("Command-H focused-window could not find parked window")
            return false
        }

        app.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        self.parkedHiddenWindow = nil
        lastStatus = "Restored focused window."
        log("Command-H focused-window restored \(app.localizedName ?? parkedHiddenWindow.localizedName)")
        return true
    }

    private func bringAppToFront(_ app: NSRunningApplication) {
        app.unhide()
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        setAppFrontmost(app)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak app] in
            guard let app, !app.isTerminated else { return }
            app.unhide()
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            self?.setAppFrontmost(app)
        }
    }

    private func hideAppsOnCurrentMonitorExceptFocused() {
        if restoreMonitorHiddenAppsIfPossible() {
            return
        }

        guard AXIsProcessTrusted() else {
            log("Command-Shift-H blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let focusedApp = NSWorkspace.shared.frontmostApplication,
              !focusedApp.isTerminated,
              focusedApp.activationPolicy == .regular else {
            lastStatus = "No focused app to keep."
            log("Command-Shift-H found no focused app")
            return
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            lastStatus = "No display found."
            log("Command-Shift-H found no displays")
            return
        }

        let sourceScreen = activeScreenForMonitorMove(from: screens)
        let sourceFrame = accessibilityScreenFrame(for: sourceScreen)
        let focusedPID = focusedApp.processIdentifier
        let focusedBundleID = focusedApp.bundleIdentifier

        let windows = windowsOnScreen(sourceFrame, excluding: nil)
        let appPIDsToHide = Set(
            windows.compactMap { window -> pid_t? in
                guard window.processIdentifier != focusedPID else { return nil }

                let app = NSWorkspace.shared.runningApplications.first {
                    $0.processIdentifier == window.processIdentifier && !$0.isTerminated
                }

                guard app?.bundleIdentifier != focusedBundleID else { return nil }
                return window.processIdentifier
            }
        )

        guard !appPIDsToHide.isEmpty else {
            lastStatus = "No other apps on this monitor."
            log("Command-Shift-H found no apps to hide on \(sourceScreen.localizedName)")
            return
        }

        suppressCommandHideObserverUntil = Date().addingTimeInterval(0.8)
        var hiddenNames: [String] = []
        var hiddenApps: [HiddenApp] = []
        for pid in appPIDsToHide {
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.processIdentifier == pid && !$0.isTerminated && $0.activationPolicy == .regular
            }) else {
                continue
            }

            let localizedName = app.localizedName ?? "App"
            _ = app.hide()
            hiddenNames.append(localizedName)
            hiddenApps.append(
                HiddenApp(
                    processIdentifier: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier,
                    localizedName: localizedName
                )
            )
        }

        focusedApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if !hiddenApps.isEmpty {
            monitorHiddenSession = MonitorHiddenSession(
                hiddenApps: hiddenApps,
                keptApp: HiddenApp(
                    processIdentifier: focusedApp.processIdentifier,
                    bundleIdentifier: focusedApp.bundleIdentifier,
                    localizedName: focusedApp.localizedName ?? "Focused app"
                ),
                screenName: sourceScreen.localizedName
            )
        }
        lastStatus = hiddenNames.isEmpty
            ? "No apps were hidden."
            : "Hidden \(hiddenNames.count) apps on this monitor."
        log("Command-Shift-H hid apps: \(hiddenNames.joined(separator: ", "))")
    }

    private func restoreMonitorHiddenAppsIfPossible() -> Bool {
        guard let session = monitorHiddenSession else { return false }
        monitorHiddenSession = nil

        suppressCommandHideObserverUntil = Date().addingTimeInterval(0.8)
        var restoredNames: [String] = []
        for hiddenApp in session.hiddenApps {
            guard let app = runningApp(for: hiddenApp), !app.isTerminated else { continue }
            app.unhide()
            restoredNames.append(app.localizedName ?? hiddenApp.localizedName)
        }

        if let keptApp = runningApp(for: session.keptApp) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, weak keptApp] in
                guard let keptApp, !keptApp.isTerminated else { return }
                keptApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                self?.setAppFrontmost(keptApp)
            }
        }

        lastStatus = restoredNames.isEmpty
            ? "Nothing to restore from this monitor hide."
            : "Restored \(restoredNames.count) apps on \(session.screenName)."
        log("Command-Shift-H restored apps: \(restoredNames.joined(separator: ", "))")
        return true
    }

    private func setAppFrontmost(_ app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    private func runningApp(for hiddenApp: HiddenApp) -> NSRunningApplication? {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == hiddenApp.processIdentifier && !$0.isTerminated
        }) {
            return app
        }

        guard let bundleIdentifier = hiddenApp.bundleIdentifier else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }
    }

    private func runningApp(for hiddenWindow: HiddenWindow) -> NSRunningApplication? {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == hiddenWindow.processIdentifier && !$0.isTerminated
        }) {
            return app
        }

        guard let bundleIdentifier = hiddenWindow.bundleIdentifier else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }
    }

    private func findWindow(for hiddenWindow: HiddenWindow, appElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.first { window in
            let title = windowStringAttribute(window, kAXTitleAttribute)
            if !hiddenWindow.title.isEmpty, title == hiddenWindow.title {
                return true
            }

            guard let storedFrame = hiddenWindow.frame,
                  let frame = windowFrame(window) else {
                return false
            }

            return abs(frame.origin.x - storedFrame.origin.x) < 10
                && abs(frame.origin.y - storedFrame.origin.y) < 10
                && abs(frame.width - storedFrame.width) < 10
                && abs(frame.height - storedFrame.height) < 10
        }
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func windowStringAttribute(_ window: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success else {
            return ""
        }

        return (value as? String) ?? ""
    }

    private struct HiddenApp {
        let processIdentifier: pid_t
        let bundleIdentifier: String?
        let localizedName: String
    }

    private struct HiddenWindow {
        let processIdentifier: pid_t
        let bundleIdentifier: String?
        let localizedName: String
        let title: String
        let frame: CGRect?
    }

    private struct MonitorHiddenSession {
        let hiddenApps: [HiddenApp]
        let keptApp: HiddenApp
        let screenName: String
    }

    private func armMoveOthersShortcut() {
        moveOthersArmedUntil = Date().addingTimeInterval(4)
        lastStatus = "Move others is ready."
        log("move others armed")
    }

    private func isMoveOthersArrowEvent(_ event: NSEvent) -> Bool {
        guard moveOthersIsArmed else { return false }

        return Self.isArrowEvent(event)
    }

    private static func isPlainArrowEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return !flags.contains(.command)
            && !flags.contains(.option)
            && !flags.contains(.control)
            && !flags.contains(.shift)
            && Self.isArrowKeyCode(event.keyCode)
    }

    private static func isArrowEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return !flags.contains(.shift) && Self.isArrowKeyCode(event.keyCode)
    }

    private nonisolated func isMoveOthersArrowEvent(_ event: CGEvent) -> Bool {
        Self.isArrowEvent(event)
    }

    private nonisolated static func isPlainArrowEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return !flags.contains(.maskControl)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
            && Self.isArrowKeyCode(UInt16(keyCode))
    }

    private nonisolated static func isArrowEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        return !flags.contains(.maskShift) && Self.isArrowKeyCode(UInt16(keyCode))
    }

    private var moveOthersIsArmed: Bool {
        guard let moveOthersArmedUntil else { return false }

        if Date() <= moveOthersArmedUntil {
            return true
        }

        self.moveOthersArmedUntil = nil
        return false
    }

    private func moveWindowsOnActiveScreenToNextScreen(excludingFocusedWindow: Bool) {
        guard AXIsProcessTrusted() else {
            log("monitor move blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        if excludingFocusedWindow {
            moveOthersArmedUntil = nil
        }

        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard screens.count > 1 else {
            lastStatus = "Only one screen is connected."
            log("only one screen connected for monitor move")
            return
        }

        let sourceScreen = activeScreenForMonitorMove(from: screens)
        if undoLastMonitorMoveIfNeeded(from: sourceScreen) {
            return
        }

        guard let sourceIndex = screens.firstIndex(of: sourceScreen) else { return }

        guard screens.count <= 2 else {
            showMonitorMoveOptions(
                screens: screens,
                sourceScreen: sourceScreen,
                excludingFocusedWindow: excludingFocusedWindow
            )
            return
        }

        let targetScreen = screens[(sourceIndex + 1) % screens.count]
        moveWindows(
            from: sourceScreen,
            to: targetScreen,
            screens: screens,
            excludingFocusedWindow: excludingFocusedWindow
        )
    }

    private func showMonitorMoveOptions(screens: [NSScreen], sourceScreen: NSScreen, excludingFocusedWindow: Bool) {
        monitorMoveOverlayPresenter.show(screens: screens, sourceScreen: sourceScreen) { [weak self] targetScreen in
            guard let self else { return }
            monitorMoveOverlayPresenter.hide()
            moveWindows(
                from: sourceScreen,
                to: targetScreen,
                screens: screens,
                excludingFocusedWindow: excludingFocusedWindow
            )
            ModifierKeySafety.releaseAfterShortcutEnds()
        }
        lastStatus = "Choose a target screen."
        log("monitor move options shown")
    }

    private func moveWindows(from sourceScreen: NSScreen, to targetScreen: NSScreen, screens: [NSScreen], excludingFocusedWindow: Bool) {
        let sourceFrame = accessibilityScreenFrame(for: sourceScreen)
        let focusedWindow = excludingFocusedWindow ? focusedWindowForExclusion() : nil
        let movableWindows = windowsOnScreen(sourceFrame, excluding: focusedWindow)

        var movedCount = 0
        var movedExternal: [MovedExternalWindow] = []
        for item in movableWindows {
            let newFrame = preservingRelativeFrame(
                item.frame,
                from: sourceScreen,
                to: targetScreen,
                usesAccessibilityCoordinates: true
            )
            setWindow(item.window, position: newFrame.origin, size: newFrame.size)
            movedCount += 1
            movedExternal.append(MovedExternalWindow(appName: item.appName, window: item.window, originalFrame: item.frame))
            log("monitor moved \(item.appName) from \(item.frame) to \(newFrame)")
        }

        let movedOwn = moveOwnWindows(
            from: sourceScreen,
            to: targetScreen,
            excludingFocusedWindow: excludingFocusedWindow && focusedWindow?.isOwnWindow == true
        )
        movedCount += movedOwn.count

        if movedCount > 0 {
            lastMonitorMoveBatch = MonitorMoveBatch(
                movedAt: Date(),
                sourceScreen: sourceScreen,
                targetScreen: targetScreen,
                externalWindows: movedExternal,
                ownWindows: movedOwn
            )
        }

        if movedCount == 0 {
            lastStatus = "No movable windows found on this monitor."
        } else {
            let targetNumber = (screens.firstIndex(of: targetScreen) ?? 0) + 1
            let label = excludingFocusedWindow ? "other windows" : "windows"
            lastStatus = "Moved \(movedCount) \(label) to Screen \(targetNumber)."
        }
        log("monitor move completed with \(movedCount) windows")
        ModifierKeySafety.releaseAfterShortcutEnds()
    }

    private func undoLastMonitorMoveIfNeeded(from activeScreen: NSScreen) -> Bool {
        guard let batch = lastMonitorMoveBatch,
              Date().timeIntervalSince(batch.movedAt) <= 2,
              activeScreen == batch.targetScreen else {
            return false
        }

        monitorMoveOverlayPresenter.hide()
        var restoredCount = 0

        for item in batch.externalWindows {
            setWindow(item.window, position: item.originalFrame.origin, size: item.originalFrame.size)
            restoredCount += 1
            log("monitor undo restored \(item.appName) to \(item.originalFrame)")
        }

        for item in batch.ownWindows {
            item.window.setFrame(item.originalFrame, display: true, animate: false)
            restoredCount += 1
            log("monitor undo restored Mac Sys Settings 2 to \(item.originalFrame)")
        }

        lastMonitorMoveBatch = nil
        lastStatus = restoredCount == 0 ? "Nothing to undo." : "Moved \(restoredCount) windows back."
        log("monitor move undo completed with \(restoredCount) windows")
        ModifierKeySafety.releaseAfterShortcutEnds()
        return true
    }

    private struct MovableWindow {
        let appName: String
        let processIdentifier: pid_t
        let window: AXUIElement
        let frame: CGRect
    }

    private func windowsOnScreen(_ sourceFrame: CGRect, excluding excludedWindow: FocusedWindowExclusion?) -> [MovableWindow] {
        NSWorkspace.shared.runningApplications.flatMap { app -> [MovableWindow] in
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  app.activationPolicy == .regular,
                  !app.isTerminated,
                  !app.isHidden else {
                return []
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            return windows(for: appElement).compactMap { window in
                if excludedWindow?.matches(window: window, processIdentifier: app.processIdentifier) == true {
                    return nil
                }

                guard let position = windowPoint(window, attribute: kAXPositionAttribute),
                      let size = windowSize(window) else {
                    return nil
                }

                let frame = CGRect(origin: position, size: size)
                guard frame.width >= 80, frame.height >= 60, mostlyIntersects(frame, sourceFrame) else {
                    return nil
                }

                return MovableWindow(
                    appName: app.localizedName ?? "window",
                    processIdentifier: app.processIdentifier,
                    window: window,
                    frame: frame
                )
            }
        }
    }

    private func windows(for appElement: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return []
        }

        return windows
    }

    private func activeScreenForMonitorMove(from screens: [NSScreen]) -> NSScreen {
        if let app = NSWorkspace.shared.frontmostApplication {
            if app.bundleIdentifier == Bundle.main.bundleIdentifier,
               let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                return screens.first { $0.frame.intersects(window.frame) } ?? window.screen ?? NSScreen.main ?? screens[0]
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            if let window = focusedWindow(for: appElement),
               let position = windowPoint(window, attribute: kAXPositionAttribute),
               let size = windowSize(window) {
                let frame = CGRect(origin: position, size: size)
                return accessibilityScreen(for: frame) ?? NSScreen.main ?? screens[0]
            }
        }

        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? screens[0]
    }

    private func moveOwnWindows(
        from sourceScreen: NSScreen,
        to targetScreen: NSScreen,
        excludingFocusedWindow: Bool
    ) -> [MovedOwnWindow] {
        let focusedOwnWindow = excludingFocusedWindow ? (NSApp.keyWindow ?? NSApp.mainWindow) : nil

        return NSApp.windows.reduce(into: []) { moved, window in
            guard window.isVisible,
                  window != focusedOwnWindow,
                  sourceScreen.visibleFrame.intersects(window.frame) else {
                return
            }

            let originalFrame = window.frame
            let newFrame = preservingRelativeFrame(
                originalFrame,
                from: sourceScreen,
                to: targetScreen,
                usesAccessibilityCoordinates: false
            )
            window.setFrame(newFrame, display: true, animate: false)
            moved.append(MovedOwnWindow(window: window, originalFrame: originalFrame))
            log("monitor moved Mac Sys Settings 2 from \(originalFrame) to \(newFrame)")
        }
    }

    private func mostlyIntersects(_ frame: CGRect, _ screenFrame: CGRect) -> Bool {
        let intersection = frame.intersection(screenFrame)
        guard !intersection.isNull else { return false }

        let frameArea = max(1, frame.width * frame.height)
        return (intersection.width * intersection.height) / frameArea >= 0.5
    }

    private func isMonitorMoveShortcutChordActive() -> Bool {
        guard MonitorMoveShortcutStore.isEnabled else { return false }

        let flags = CGEventSource.flagsState(.combinedSessionState)
        return flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && flags.contains(.maskCommand)
    }

    private func focusedWindowForExclusion() -> FocusedWindowExclusion? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return nil }
            return FocusedWindowExclusion(processIdentifier: app.processIdentifier, window: nil, ownWindow: window)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement) else { return nil }
        return FocusedWindowExclusion(processIdentifier: app.processIdentifier, window: window, ownWindow: nil)
    }

    private struct FocusedWindowExclusion {
        let processIdentifier: pid_t
        let window: AXUIElement?
        let ownWindow: NSWindow?

        var isOwnWindow: Bool {
            ownWindow != nil
        }

        func matches(window candidate: AXUIElement, processIdentifier candidatePID: pid_t) -> Bool {
            guard candidatePID == processIdentifier else { return false }
            guard let window else { return true }
            return CFEqual(candidate, window)
        }
    }

    private struct MonitorMoveBatch {
        let movedAt: Date
        let sourceScreen: NSScreen
        let targetScreen: NSScreen
        let externalWindows: [MovedExternalWindow]
        let ownWindows: [MovedOwnWindow]
    }

    private struct MovedExternalWindow {
        let appName: String
        let window: AXUIElement
        let originalFrame: CGRect
    }

    private struct MovedOwnWindow {
        let window: NSWindow
        let originalFrame: CGRect
    }

    private struct SnapTarget {
        let appName: String
        let processIdentifier: pid_t
        let window: AXUIElement?
        let ownWindow: NSWindow?
        let frame: CGRect
        let screenFrame: CGRect
        let usesAccessibilityCoordinates: Bool
        let snapKey: String
    }

    private enum SnapSide {
        case left
        case right
        case up
        case down
    }

    private struct BrowserTabSnapDefinition {
        let bundleIdentifier: String
        let appName: String
        let usesChromeScripting: Bool
    }

    private struct BrowserTabPairCandidate {
        let definition: BrowserTabSnapDefinition
        let sourceWindowID: String
        let firstTargetWindowID: String?
        let firstSide: SnapSide
        let sourceFrame: CGRect
        let sourceScreenFrame: CGRect
        let firstCreatedNewWindow: Bool
        let expiresAt: Date
    }

    private let browserTabSnapDefinitions = [
        BrowserTabSnapDefinition(bundleIdentifier: "com.google.Chrome", appName: "Google Chrome", usesChromeScripting: true),
        BrowserTabSnapDefinition(bundleIdentifier: "com.microsoft.edgemac", appName: "Microsoft Edge", usesChromeScripting: true),
        BrowserTabSnapDefinition(bundleIdentifier: "com.apple.Safari", appName: "Safari", usesChromeScripting: false)
    ]

    private func snapFrontWindow(to side: SnapSide) {
        guard AXIsProcessTrusted() else {
            log("snap blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let target = reusableSnapTarget() ?? focusedSnapTarget() ?? snapTargetUnderMouse() else {
            lastStatus = "No window found for snap."
            log("no mouse or focused window found for snap")
            return
        }

        let newFrame = snappingFrame(
            for: target.frame,
            in: target.screenFrame,
            side: side,
            usesAccessibilityCoordinates: target.usesAccessibilityCoordinates,
            snapKey: target.snapKey
        )

        if let ownWindow = target.ownWindow {
            setOwnWindowSmoothly(
                ownWindow,
                from: target.frame,
                to: newFrame,
                side: side,
                screenFrame: target.screenFrame,
                snapKey: target.snapKey
            )
            ownWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else if let window = target.window {
            if isChromeSnapTarget(target) {
                setChromeFrontWindowSmoothly(
                    from: target.frame,
                    to: newFrame,
                    side: side,
                    screenFrame: target.screenFrame
                )
            } else {
                setWindowSmoothly(
                    window,
                    from: target.frame,
                    to: newFrame,
                    side: side,
                    screenFrame: target.screenFrame,
                    usesAccessibilityCoordinates: target.usesAccessibilityCoordinates,
                    snapKey: target.snapKey
                )
                if side == .down {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                        self?.alignBottomRightAfterResize(window, in: target.screenFrame, usesAccessibilityCoordinates: true, snapKey: target.snapKey)
                    }
                }
            }
        }

        lastStatus = statusText(for: side)
        activeSnapTarget = target
        activeSnapTargetUntil = Date().addingTimeInterval(0.75)
        log("snapped \(target.appName) \(side) from \(target.frame) to \(newFrame)")

        if side == .left || side == .right,
           let definition = browserTabSnapDefinition(for: target) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
                self?.pressTheaterModeIfYouTube(in: definition)
            }
        }
    }

    private func browserTabSnapDefinition(for target: SnapTarget) -> BrowserTabSnapDefinition? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == target.processIdentifier && !$0.isTerminated
        }) else {
            return nil
        }

        return browserTabSnapDefinitions.first { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func snapActiveBrowserTab(to side: SnapSide) {
        guard AXIsProcessTrusted() else {
            log("browser tab snap blocked by missing Accessibility permission")
            requestAccessibilityAccess()
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let definition = browserTabSnapDefinitions.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            lastStatus = "Command-Option-Arrow tab snap works in Chrome, Safari, and Edge."
            log("browser tab snap ignored for unsupported app \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")")
            return
        }

        let sourceTarget = focusedSnapTarget()
        let pairCandidate = browserTabPairCandidate
        let shouldUsePair = shouldUseBrowserTabPair(for: definition, side: side)

        if shouldUsePair, let pairCandidate {
            if pairCandidate.firstCreatedNewWindow {
                _ = focusBrowserWindow(definition, windowID: pairCandidate.sourceWindowID)
            } else {
                focusNextBrowserWindowOnSameScreen(after: pairCandidate)
            }
        }

        let result = runBrowserTabSnapScript(definition)
        guard result.success else {
            lastStatus = result.message
            log("browser tab snap failed: \(result.message)")
            if shouldUsePair {
                browserTabPairCandidate = nil
            }
            return
        }

        updateBrowserTabPairCandidate(
            definition: definition,
            side: side,
            sourceWindowID: result.sourceWindowID,
            targetWindowID: result.targetWindowID,
            sourceTarget: sourceTarget,
            createdNewWindow: result.createdNewWindow,
            usedPair: shouldUsePair
        )

        activeSnapTarget = nil
        activeSnapTargetUntil = Date.distantPast
        lastStatus = shouldUsePair
            ? "Snapping next \(definition.appName) tab \(side == .left ? "left" : "right")."
            : "Snapping \(definition.appName) tab \(side == .left ? "left" : "right")."
        log("browser tab snap script result \(result.message)")

        DispatchQueue.main.asyncAfter(deadline: .now() + result.snapDelay) { [weak self] in
            guard let self else { return }
            if let targetWindowID = result.targetWindowID {
                _ = self.focusBrowserWindow(definition, windowID: targetWindowID)
            }
            self.snapFrontWindow(to: side)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                self?.pressTheaterModeIfYouTube(in: definition)
            }
        }
    }

    private func shouldUseBrowserTabPair(for definition: BrowserTabSnapDefinition, side: SnapSide) -> Bool {
        guard BrowserTabSnapStore.quickOppositeArrowEnabled,
              let candidate = browserTabPairCandidate,
              candidate.expiresAt > Date(),
              candidate.definition.bundleIdentifier == definition.bundleIdentifier,
              candidate.firstSide != side else {
            return false
        }

        return true
    }

    private func updateBrowserTabPairCandidate(
        definition: BrowserTabSnapDefinition,
        side: SnapSide,
        sourceWindowID: String?,
        targetWindowID: String?,
        sourceTarget: SnapTarget?,
        createdNewWindow: Bool,
        usedPair: Bool
    ) {
        if usedPair {
            browserTabPairCandidate = nil
            return
        }

        guard BrowserTabSnapStore.quickOppositeArrowEnabled,
              let sourceWindowID,
              let sourceTarget,
              !sourceWindowID.isEmpty else {
            browserTabPairCandidate = nil
            return
        }

        browserTabPairCandidate = BrowserTabPairCandidate(
            definition: definition,
            sourceWindowID: sourceWindowID,
            firstTargetWindowID: targetWindowID,
            firstSide: side,
            sourceFrame: sourceTarget.frame,
            sourceScreenFrame: sourceTarget.screenFrame,
            firstCreatedNewWindow: createdNewWindow,
            expiresAt: Date().addingTimeInterval(0.5)
        )
    }

    private func pressTheaterModeIfYouTube(in definition: BrowserTabSnapDefinition) {
        let script = definition.usesChromeScripting
            ? chromeStyleYouTubeTheaterScript(appName: definition.appName)
            : safariYouTubeTheaterScript()

        var error: NSDictionary?
        let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue ?? ""

        if error != nil {
            log("YouTube theater check failed for \(definition.appName)")
        } else if output == "theater" {
            log("pressed YouTube theater mode for \(definition.appName)")
        } else if output == "already-theater" {
            log("YouTube theater mode already active for \(definition.appName)")
        }
    }

    private func runBrowserTabSnapScript(_ definition: BrowserTabSnapDefinition) -> (success: Bool, message: String, snapDelay: TimeInterval, sourceWindowID: String?, targetWindowID: String?, createdNewWindow: Bool) {
        let script = definition.usesChromeScripting
            ? chromeStyleBrowserTabSnapScript(appName: definition.appName)
            : safariBrowserTabSnapScript()

        var error: NSDictionary?
        let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue ?? ""

        if error != nil {
            return (false, "\(definition.appName) would not move the active tab.", 0, nil, nil, false)
        }

        let parts = output.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let status = parts.first ?? output
        let sourceWindowID = parts.count > 1 ? parts[1] : nil
        let targetWindowID = parts.count > 2 ? parts[2] : sourceWindowID

        switch status {
        case "created-window":
            return (true, "Created a new \(definition.appName) window for the tab.", 0.35, sourceWindowID, targetWindowID, true)
        case "already-window":
            return (true, "The active tab is already its own window.", 0.05, sourceWindowID, targetWindowID, false)
        case "empty-url":
            return (false, "This tab cannot be moved yet.", 0, nil, nil, false)
        case "no-window":
            return (false, "No browser window found.", 0, nil, nil, false)
        default:
            return (true, output.isEmpty ? "Browser tab ready." : output, 0.25, nil, nil, false)
        }
    }

    private func focusBrowserWindow(_ definition: BrowserTabSnapDefinition, windowID: String) -> Bool {
        let script = definition.usesChromeScripting
            ? chromeStyleFocusWindowScript(appName: definition.appName, windowID: windowID)
            : safariFocusWindowScript(windowID: windowID)

        var error: NSDictionary?
        let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue ?? ""
        if error != nil {
            log("browser tab pair could not focus source window \(windowID)")
            return false
        } else {
            log("browser tab pair focus source result \(output)")
            return output == "focused"
        }
    }

    private func focusNextBrowserWindowOnSameScreen(after candidate: BrowserTabPairCandidate) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == candidate.definition.bundleIdentifier && !$0.isTerminated
        }) else {
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let firstExpectedFrame = snappingFrame(
            for: candidate.sourceFrame,
            in: candidate.sourceScreenFrame,
            side: candidate.firstSide,
            usesAccessibilityCoordinates: true,
            snapKey: nil
        )

        let candidates = windows(for: appElement).compactMap { window -> (window: AXUIElement, frame: CGRect)? in
            guard let position = windowPoint(window, attribute: kAXPositionAttribute),
                  let size = windowSize(window) else { return nil }
            let frame = CGRect(origin: position, size: size)
            guard mostlyIntersects(frame, candidate.sourceScreenFrame),
                  !framesAreClose(frame, firstExpectedFrame) else {
                return nil
            }
            return (window, frame)
        }

        guard let target = candidates.first else {
            log("browser tab pair found no next same-screen browser window")
            return
        }

        let main = true as CFTypeRef
        AXUIElementSetAttributeValue(target.window, kAXMainAttribute as CFString, main)
        AXUIElementPerformAction(target.window, kAXRaiseAction as CFString)
        app.activate(options: [.activateAllWindows])
        log("browser tab pair focused next same-screen \(candidate.definition.appName) window at \(target.frame)")
    }

    private func chromeStyleBrowserTabSnapScript(appName: String) -> String {
        """
        tell application "\(appName)"
            if not (exists front window) then return "no-window"
            set sourceWindow to front window
            set sourceWindowID to id of sourceWindow as text
            if (count of tabs of sourceWindow) is less than or equal to 1 then
                activate
                return "already-window|" & sourceWindowID & "|" & sourceWindowID
            end if
            activate
        end tell
        delay 0.08
        tell application "System Events"
            tell process "\(appName)"
                click menu item "Move Tab to New Window" of menu 1 of menu bar item "Tab" of menu bar 1
            end tell
        end tell
        delay 0.18
        tell application "\(appName)"
            activate
            set targetWindowID to id of front window as text
        end tell
        return "created-window|" & sourceWindowID & "|" & targetWindowID
        """
    }

    private func chromeStyleFocusWindowScript(appName: String, windowID: String) -> String {
        """
        tell application "\(appName)"
            set targetID to \(windowID)
            repeat with browserWindow in windows
                if id of browserWindow is targetID then
                    set index of browserWindow to 1
                    activate
                    return "focused"
                end if
            end repeat
            activate
            return "missing-window"
        end tell
        """
    }

    private func safariBrowserTabSnapScript() -> String {
        """
        tell application "Safari"
            if not (exists front window) then return "no-window"
            set sourceWindow to front window
            set sourceWindowID to id of sourceWindow as text
            set sourceTab to current tab of sourceWindow
            set tabURL to URL of sourceTab
            if tabURL is missing value or tabURL is "" then return "empty-url"
            if (count of tabs of sourceWindow) is less than or equal to 1 then
                activate
                return "already-window|" & sourceWindowID & "|" & sourceWindowID
            end if
            make new document with properties {URL:tabURL}
            delay 0.05
            set targetWindowID to id of front window as text
            close sourceTab
            activate
            return "created-window|" & sourceWindowID & "|" & targetWindowID
        end tell
        """
    }

    private func safariFocusWindowScript(windowID: String) -> String {
        """
        tell application "Safari"
            set targetID to \(windowID)
            repeat with browserWindow in windows
                if id of browserWindow is targetID then
                    set index of browserWindow to 1
                    activate
                    return "focused"
                end if
            end repeat
            activate
            return "missing-window"
        end tell
        """
    }

    private func chromeStyleYouTubeTheaterScript(appName: String) -> String {
        """
        tell application "\(appName)"
            if not (exists front window) then return "no-window"
            set tabURL to URL of active tab of front window
            if tabURL does not contain "youtube.com/watch" and tabURL does not contain "youtu.be/" then return "not-youtube"
            try
                set theaterModeActive to execute active tab of front window javascript "(() => { const flexy = document.querySelector('ytd-watch-flexy'); return !!(flexy && (flexy.hasAttribute('theater') || flexy.hasAttribute('theater-requested_'))); })();"
                if theaterModeActive is true or theaterModeActive is "true" then return "already-theater"
            end try
            activate
        end tell
        delay 0.05
        tell application "System Events"
            key code 17
        end tell
        return "theater"
        """
    }

    private func safariYouTubeTheaterScript() -> String {
        """
        tell application "Safari"
            if not (exists front window) then return "no-window"
            set tabURL to URL of current tab of front window
            if tabURL does not contain "youtube.com/watch" and tabURL does not contain "youtu.be/" then return "not-youtube"
            try
                set theaterModeActive to do JavaScript "(() => { const flexy = document.querySelector('ytd-watch-flexy'); return !!(flexy && (flexy.hasAttribute('theater') || flexy.hasAttribute('theater-requested_'))); })();" in current tab of front window
                if theaterModeActive is true or theaterModeActive is "true" then return "already-theater"
            end try
            activate
        end tell
        delay 0.05
        tell application "System Events"
            key code 17
        end tell
        return "theater"
        """
    }

    private func reusableSnapTarget() -> SnapTarget? {
        guard Date() < activeSnapTargetUntil,
              let target = activeSnapTarget else {
            activeSnapTarget = nil
            return nil
        }

        if let ownWindow = target.ownWindow {
            guard ownWindow.isVisible else { return nil }
            let screen = ownWindow.screen ?? accessibilityScreen(for: ownWindow.frame) ?? NSScreen.main ?? NSScreen.screens[0]
            return SnapTarget(
                appName: target.appName,
                processIdentifier: target.processIdentifier,
                window: nil,
                ownWindow: ownWindow,
                frame: ownWindow.frame,
                screenFrame: screen.visibleFrame,
                usesAccessibilityCoordinates: false,
                snapKey: target.snapKey
            )
        }

        guard let window = target.window,
              let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            activeSnapTarget = nil
            return nil
        }

        let frame = CGRect(origin: position, size: size)
        let screen = accessibilityScreen(for: frame) ?? NSScreen.main ?? NSScreen.screens[0]
        return SnapTarget(
            appName: target.appName,
            processIdentifier: target.processIdentifier,
            window: window,
            ownWindow: nil,
            frame: frame,
            screenFrame: accessibilityScreenFrame(for: screen),
            usesAccessibilityCoordinates: target.usesAccessibilityCoordinates,
            snapKey: target.snapKey
        )
    }

    private func snapTargetUnderMouse() -> SnapTarget? {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return nil }
        let windowInfos = visibleWindowInfos()

        if let windowInfo = windowInfos.first(where: { info in
            guard let frame = info.frame else { return false }
            return frame.contains(mouseLocation)
        }),
           let target = snapTarget(from: windowInfo) {
            return target
        }

        guard let screen = NSScreen.screens.first(where: { accessibilityScreenFrame(for: $0).contains(mouseLocation) }) else {
            return nil
        }

        let screenFrame = accessibilityScreenFrame(for: screen)
        guard let windowInfo = windowInfos.first(where: { info in
            guard let frame = info.frame else { return false }
            return mostlyIntersects(frame, screenFrame)
        }) else {
            return nil
        }

        return snapTarget(from: windowInfo)
    }

    private func focusedSnapTarget() -> SnapTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else { return nil }
            let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
            return SnapTarget(
                appName: "Mac Sys Settings 2",
                processIdentifier: app.processIdentifier,
                window: nil,
                ownWindow: window,
                frame: window.frame,
                screenFrame: screen.visibleFrame,
                usesAccessibilityCoordinates: false,
                snapKey: "self-\(ObjectIdentifier(window).hashValue)"
            )
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = focusedWindow(for: appElement),
              let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else {
            return nil
        }

        let frame = CGRect(origin: position, size: size)
        let screen = accessibilityScreen(for: frame) ?? NSScreen.main ?? NSScreen.screens[0]
        return SnapTarget(
            appName: app.localizedName ?? "window",
            processIdentifier: app.processIdentifier,
            window: window,
            ownWindow: nil,
            frame: frame,
            screenFrame: accessibilityScreenFrame(for: screen),
            usesAccessibilityCoordinates: true,
            snapKey: "\(app.processIdentifier)"
        )
    }

    private func snapTarget(from windowInfo: WindowInfo) -> SnapTarget? {
        guard let frame = windowInfo.frame else { return nil }

        if windowInfo.processIdentifier == getpid() {
            guard let ownWindow = NSApp.windows.first(where: { $0.windowNumber == windowInfo.windowNumber })
                    ?? NSApp.windows.first(where: { framesAreClose($0.frame, frame) }) else {
                return nil
            }

            let screen = ownWindow.screen ?? accessibilityScreen(for: frame) ?? NSScreen.main ?? NSScreen.screens[0]
            return SnapTarget(
                appName: "Mac Sys Settings 2",
                processIdentifier: windowInfo.processIdentifier,
                window: nil,
                ownWindow: ownWindow,
                frame: ownWindow.frame,
                screenFrame: screen.visibleFrame,
                usesAccessibilityCoordinates: false,
                snapKey: "self-\(ObjectIdentifier(ownWindow).hashValue)"
            )
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == windowInfo.processIdentifier && !$0.isTerminated
        }) else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(windowInfo.processIdentifier)
        guard let window = windows(for: appElement).first(where: { candidate in
            guard let position = windowPoint(candidate, attribute: kAXPositionAttribute),
                  let size = windowSize(candidate) else { return false }
            return framesAreClose(CGRect(origin: position, size: size), frame)
        }) ?? focusedWindow(for: appElement) else {
            return nil
        }

        guard let position = windowPoint(window, attribute: kAXPositionAttribute),
              let size = windowSize(window) else { return nil }

        let axFrame = CGRect(origin: position, size: size)
        let screen = accessibilityScreen(for: axFrame) ?? NSScreen.main ?? NSScreen.screens[0]
        return SnapTarget(
            appName: app.localizedName ?? windowInfo.ownerName,
            processIdentifier: windowInfo.processIdentifier,
            window: window,
            ownWindow: nil,
            frame: axFrame,
            screenFrame: accessibilityScreenFrame(for: screen),
            usesAccessibilityCoordinates: true,
            snapKey: "\(windowInfo.processIdentifier)"
        )
    }

    private struct WindowInfo {
        let ownerName: String
        let processIdentifier: pid_t
        let windowNumber: Int
        let frame: CGRect?
    }

    private func visibleWindowInfos() -> [WindowInfo] {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawWindows.compactMap { info in
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0 else { return nil }

            guard let ownerName = info[kCGWindowOwnerName as String] as? String,
                  let processIdentifier = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowNumber = info[kCGWindowNumber as String] as? Int else {
                return nil
            }

            let frame = windowFrame(from: info[kCGWindowBounds as String])
            guard let frame, frame.width >= 80, frame.height >= 60 else { return nil }

            return WindowInfo(
                ownerName: ownerName,
                processIdentifier: processIdentifier,
                windowNumber: windowNumber,
                frame: frame
            )
        }
    }

    private func windowFrame(from value: Any?) -> CGRect? {
        guard let dictionary = value as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }

    private func framesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 8
            && abs(lhs.minY - rhs.minY) <= 8
            && abs(lhs.width - rhs.width) <= 16
            && abs(lhs.height - rhs.height) <= 16
    }

    private func snappingFrame(for currentFrame: CGRect, in screenFrame: CGRect, side: SnapSide, usesAccessibilityCoordinates: Bool, snapKey: String? = nil) -> CGRect {
        if side == .up {
            if let snapKey {
                downSnapLevels.removeValue(forKey: snapKey)
                horizontalSnapLevels.removeValue(forKey: horizontalSnapKey(snapKey: snapKey, side: .left))
                horizontalSnapLevels.removeValue(forKey: horizontalSnapKey(snapKey: snapKey, side: .right))
                horizontalSnapFrames.removeValue(forKey: horizontalSnapKey(snapKey: snapKey, side: .left))
                horizontalSnapFrames.removeValue(forKey: horizontalSnapKey(snapKey: snapKey, side: .right))
            }

            return CGRect(
                x: screenFrame.minX.rounded(.toNearestOrAwayFromZero),
                y: screenFrame.minY.rounded(.toNearestOrAwayFromZero),
                width: screenFrame.width.rounded(.toNearestOrAwayFromZero),
                height: screenFrame.height.rounded(.toNearestOrAwayFromZero)
            )
        }

        if side == .down {
            let level = nextDownSnapLevel(for: snapKey, currentFrame: currentFrame, screenFrame: screenFrame, usesAccessibilityCoordinates: usesAccessibilityCoordinates)
            let targetSize = downSnapSize(level: level, currentFrame: currentFrame, screenFrame: screenFrame)
            let width = targetSize.width.rounded(.toNearestOrAwayFromZero)
            let height = targetSize.height.rounded(.toNearestOrAwayFromZero)
            let y = usesAccessibilityCoordinates ? screenFrame.maxY - height : screenFrame.minY
            return CGRect(
                x: (screenFrame.maxX - width).rounded(.toNearestOrAwayFromZero),
                y: y.rounded(.toNearestOrAwayFromZero),
                width: width,
                height: height
            )
        }

        if let snapKey {
            downSnapLevels.removeValue(forKey: snapKey)
        }

        let fractions: [CGFloat] = [0.5, 1.0 / 3.0, 2.0 / 3.0]
        let currentFraction = screenFrame.width == 0 ? 0.5 : currentFrame.width / screenFrame.width
        let edgeThreshold: CGFloat = 36
        let isOnRequestedSide: Bool

        switch side {
        case .left:
            isOnRequestedSide = abs(currentFrame.minX - screenFrame.minX) <= edgeThreshold
        case .right:
            isOnRequestedSide = abs(currentFrame.maxX - screenFrame.maxX) <= edgeThreshold
        case .up, .down:
            isOnRequestedSide = false
        }

        let targetFraction: CGFloat
        if let snapKey {
            let sideKey = horizontalSnapKey(snapKey: snapKey, side: side)
            let oppositeKey = horizontalSnapKey(snapKey: snapKey, side: side == .left ? .right : .left)
            horizontalSnapLevels.removeValue(forKey: oppositeKey)
            horizontalSnapFrames.removeValue(forKey: oppositeKey)

            let nextIndex: Int
            if isOnRequestedSide {
                if let storedIndex = horizontalSnapLevels[sideKey],
                   let lastSnapFrame = horizontalSnapFrames[sideKey],
                   snappedFramesAreClose(currentFrame, lastSnapFrame) {
                    nextIndex = (storedIndex + 1) % fractions.count
                } else if horizontalSnapLevels[sideKey] == nil,
                          let currentIndex = fractions.firstIndex(where: { abs(currentFraction - $0) <= 0.08 }) {
                    nextIndex = (currentIndex + 1) % fractions.count
                } else {
                    nextIndex = 0
                }
            } else {
                nextIndex = 0
            }

            horizontalSnapLevels[sideKey] = nextIndex
            targetFraction = fractions[nextIndex]
        } else if isOnRequestedSide,
                  let currentIndex = fractions.firstIndex(where: { abs(currentFraction - $0) <= 0.08 }) {
            targetFraction = fractions[(currentIndex + 1) % fractions.count]
        } else {
            targetFraction = fractions[0]
        }

        let y = screenFrame.minY.rounded(.toNearestOrAwayFromZero)
        let height = screenFrame.height.rounded(.toNearestOrAwayFromZero)

        if abs(targetFraction - (1.0 / 3.0)) <= 0.001 {
            let splitX = screenFrame.minX + floor(screenFrame.width / 3.0)
            let rightX = screenFrame.minX + floor(screenFrame.width * 2.0 / 3.0)
            let x = side == .left ? screenFrame.minX : rightX
            let width = side == .left ? splitX - screenFrame.minX : screenFrame.maxX - rightX
            let frame = CGRect(x: x.rounded(.toNearestOrAwayFromZero), y: y, width: max(160, width.rounded(.toNearestOrAwayFromZero)), height: height)
            rememberHorizontalSnapFrame(frame, snapKey: snapKey, side: side)
            return frame
        }

        if abs(targetFraction - (2.0 / 3.0)) <= 0.001 {
            let leftWidth = floor(screenFrame.width * 2.0 / 3.0)
            let rightX = screenFrame.minX + floor(screenFrame.width / 3.0)
            let x = side == .left ? screenFrame.minX : rightX
            let width = side == .left ? leftWidth : screenFrame.maxX - rightX
            let frame = CGRect(x: x.rounded(.toNearestOrAwayFromZero), y: y, width: max(160, width.rounded(.toNearestOrAwayFromZero)), height: height)
            rememberHorizontalSnapFrame(frame, snapKey: snapKey, side: side)
            return frame
        }

        let width = max(160, (screenFrame.width * targetFraction).rounded(.toNearestOrAwayFromZero))
        let x = side == .left ? screenFrame.minX : screenFrame.maxX - width

        let frame = CGRect(x: x.rounded(.toNearestOrAwayFromZero), y: y, width: width, height: height)
        rememberHorizontalSnapFrame(frame, snapKey: snapKey, side: side)
        return frame
    }

    private func horizontalSnapKey(snapKey: String, side: SnapSide) -> String {
        "\(snapKey)-\(side)"
    }

    private func rememberHorizontalSnapFrame(_ frame: CGRect, snapKey: String?, side: SnapSide) {
        guard let snapKey else { return }
        horizontalSnapFrames[horizontalSnapKey(snapKey: snapKey, side: side)] = frame
    }

    private func snappedFramesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 28
            && abs(lhs.minY - rhs.minY) <= 28
            && abs(lhs.width - rhs.width) <= 56
            && abs(lhs.height - rhs.height) <= 56
    }

    private func statusText(for side: SnapSide) -> String {
        switch side {
        case .left:
            return "Snapped left."
        case .right:
            return "Snapped right."
        case .up:
            return "Filled screen."
        case .down:
            return "Shrunk bottom right."
        }
    }

    private func nextDownSnapLevel(for snapKey: String?, currentFrame: CGRect, screenFrame: CGRect, usesAccessibilityCoordinates: Bool) -> Int {
        guard let snapKey else { return 0 }

        let currentLevel = downSnapLevels[snapKey]
        let isBottomRight = isBottomRightFrame(currentFrame, in: screenFrame, usesAccessibilityCoordinates: usesAccessibilityCoordinates)
        let isCompact = currentFrame.width <= screenFrame.width * 0.38 && currentFrame.height <= screenFrame.height * 0.45
        let nextLevel = (isBottomRight && isCompact) ? ((currentLevel ?? 0) + 1) % 3 : 0
        downSnapLevels[snapKey] = nextLevel
        return nextLevel
    }

    private func baseDownSnapSize(in screenFrame: CGRect) -> CGSize {
        CGSize(
            width: min(max(360, screenFrame.width * 0.22), 520),
            height: min(max(220, screenFrame.height * 0.22), 340)
        )
    }

    private func downSnapSize(level: Int, currentFrame: CGRect, screenFrame: CGRect) -> CGSize {
        guard level > 0 else {
            return baseDownSnapSize(in: screenFrame)
        }

        return CGSize(
            width: min(screenFrame.width, currentFrame.width * 1.1),
            height: min(screenFrame.height, currentFrame.height * 1.1)
        )
    }

    private func isBottomRightFrame(_ frame: CGRect, in screenFrame: CGRect, usesAccessibilityCoordinates: Bool) -> Bool {
        let edgeThreshold: CGFloat = 44
        let rightAligned = abs(frame.maxX - screenFrame.maxX) <= edgeThreshold
        let bottomEdge = usesAccessibilityCoordinates ? screenFrame.maxY : screenFrame.minY + frame.height
        let currentBottomEdge = usesAccessibilityCoordinates ? frame.maxY : frame.minY + frame.height
        return rightAligned && abs(currentBottomEdge - bottomEdge) <= edgeThreshold
    }

    private func alignBottomRightAfterResize(_ window: AXUIElement, in screenFrame: CGRect, usesAccessibilityCoordinates: Bool, snapKey: String?) {
        repositionWindowBottomRight(window, in: screenFrame, usesAccessibilityCoordinates: usesAccessibilityCoordinates)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.repositionWindowBottomRight(window, in: screenFrame, usesAccessibilityCoordinates: usesAccessibilityCoordinates)
        }
    }

    private func repositionWindowBottomRight(_ window: AXUIElement, in screenFrame: CGRect, usesAccessibilityCoordinates: Bool) {
        guard let size = windowSize(window) else { return }

        let x = (screenFrame.maxX - size.width).rounded(.toNearestOrAwayFromZero)
        let y = usesAccessibilityCoordinates
            ? (screenFrame.maxY - size.height).rounded(.toNearestOrAwayFromZero)
            : screenFrame.minY.rounded(.toNearestOrAwayFromZero)

        setWindow(window, position: CGPoint(x: x, y: y), size: size)
    }

    private func setOwnWindowSmoothly(
        _ window: NSWindow,
        from currentFrame: CGRect,
        to targetFrame: CGRect,
        side: SnapSide,
        screenFrame: CGRect,
        snapKey: String
    ) {
        let token = nextSnapAnimationToken(for: snapKey)
        let frames = steppedFrames(from: currentFrame, to: targetFrame)

        for (index, frame) in frames.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.035) { [weak self, weak window] in
                guard let self, self.snapAnimationTokens[snapKey] == token, let window else { return }
                window.setFrame(frame, display: true, animate: false)
                if index == frames.count - 1 {
                    self.settleOwnSnappedWindow(window, targetFrame: targetFrame, side: side, screenFrame: screenFrame)
                    self.snapAnimationTokens.removeValue(forKey: snapKey)
                }
            }
        }
    }

    private func setWindowSmoothly(
        _ window: AXUIElement,
        from currentFrame: CGRect,
        to targetFrame: CGRect,
        side: SnapSide,
        screenFrame: CGRect,
        usesAccessibilityCoordinates: Bool,
        snapKey: String
    ) {
        let token = nextSnapAnimationToken(for: snapKey)
        let frames = steppedFrames(from: currentFrame, to: targetFrame)

        for (index, frame) in frames.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.035) { [weak self] in
                guard let self, self.snapAnimationTokens[snapKey] == token else { return }
                self.setWindow(window, position: frame.origin, size: frame.size)
                if index == frames.count - 1 {
                    self.settleSnappedWindow(
                        window,
                        targetFrame: targetFrame,
                        side: side,
                        screenFrame: screenFrame,
                        usesAccessibilityCoordinates: usesAccessibilityCoordinates
                    )
                    if side == .left || side == .right {
                        self.nudgeBrowserResizeIfNeeded(
                            window,
                            side: side,
                            screenFrame: screenFrame,
                            usesAccessibilityCoordinates: usesAccessibilityCoordinates
                        )
                    }
                    self.snapAnimationTokens.removeValue(forKey: snapKey)
                }
            }
        }
    }

    private func isChromeSnapTarget(_ target: SnapTarget) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.processIdentifier == target.processIdentifier && $0.bundleIdentifier == "com.google.Chrome"
        }
    }

    private func setChromeFrontWindowSmoothly(
        from currentFrame: CGRect,
        to targetFrame: CGRect,
        side: SnapSide,
        screenFrame: CGRect
    ) {
        let frames = steppedFrames(from: currentFrame, to: targetFrame)

        for (index, frame) in frames.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.035) {
                Self.setChromeFrontWindowBounds(frame)
            }
        }

        guard side == .left || side == .right else { return }

        let nudgeSize = CGSize(width: max(160, targetFrame.width - 2), height: targetFrame.height)
        let nudgeOrigin = settledOrigin(
            for: nudgeSize,
            targetFrame: CGRect(origin: .zero, size: nudgeSize),
            side: side,
            screenFrame: screenFrame,
            usesAccessibilityCoordinates: true
        )
        let nudgeFrame = CGRect(origin: nudgeOrigin, size: nudgeSize)

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(frames.count) * 0.035 + 0.06) {
            Self.setChromeFrontWindowBounds(nudgeFrame)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(frames.count) * 0.035 + 0.16) {
            Self.setChromeFrontWindowBounds(targetFrame)
        }
    }

    private nonisolated static func setChromeFrontWindowBounds(_ frame: CGRect) {
        let left = Int(frame.minX.rounded(.toNearestOrAwayFromZero))
        let top = Int(frame.minY.rounded(.toNearestOrAwayFromZero))
        let right = Int(frame.maxX.rounded(.toNearestOrAwayFromZero))
        let bottom = Int(frame.maxY.rounded(.toNearestOrAwayFromZero))

        let script = """
        tell application id "com.google.Chrome"
            if (count of windows) > 0 then
                set bounds of front window to {\(left), \(top), \(right), \(bottom)}
            end if
        end tell
        """

        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    private func settleOwnSnappedWindow(_ window: NSWindow, targetFrame: CGRect, side: SnapSide, screenFrame: CGRect) {
        var frame = window.frame
        frame.origin = settledOrigin(for: frame.size, targetFrame: targetFrame, side: side, screenFrame: screenFrame, usesAccessibilityCoordinates: false)
        window.setFrame(frame, display: true, animate: false)
    }

    private func settleSnappedWindow(
        _ window: AXUIElement,
        targetFrame: CGRect,
        side: SnapSide,
        screenFrame: CGRect,
        usesAccessibilityCoordinates: Bool
    ) {
        guard let actualSize = windowSize(window) else { return }
        let origin = settledOrigin(
            for: actualSize,
            targetFrame: targetFrame,
            side: side,
            screenFrame: screenFrame,
            usesAccessibilityCoordinates: usesAccessibilityCoordinates
        )
        setWindow(window, position: origin, size: actualSize)
    }

    private func settledOrigin(
        for actualSize: CGSize,
        targetFrame: CGRect,
        side: SnapSide,
        screenFrame: CGRect,
        usesAccessibilityCoordinates: Bool
    ) -> CGPoint {
        var x = targetFrame.minX
        var y = targetFrame.minY

        switch side {
        case .left, .up:
            x = screenFrame.minX
        case .right, .down:
            x = screenFrame.maxX - actualSize.width
        }

        switch side {
        case .left, .right, .up:
            y = usesAccessibilityCoordinates ? screenFrame.minY : screenFrame.maxY - actualSize.height
        case .down:
            y = usesAccessibilityCoordinates ? screenFrame.maxY - actualSize.height : screenFrame.minY
        }

        x = min(max(x, screenFrame.minX), screenFrame.maxX - min(actualSize.width, screenFrame.width))
        y = min(max(y, screenFrame.minY), screenFrame.maxY - min(actualSize.height, screenFrame.height))

        return CGPoint(
            x: x.rounded(.toNearestOrAwayFromZero),
            y: y.rounded(.toNearestOrAwayFromZero)
        )
    }

    private func nudgeBrowserResizeIfNeeded(
        _ window: AXUIElement,
        side: SnapSide,
        screenFrame: CGRect,
        usesAccessibilityCoordinates: Bool
    ) {
        guard let finalSize = windowSize(window), finalSize.width > 220 else { return }

        let nudgeSize = CGSize(width: max(160, finalSize.width - 2), height: finalSize.height)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            let nudgeOrigin = self.settledOrigin(
                for: nudgeSize,
                targetFrame: CGRect(origin: .zero, size: nudgeSize),
                side: side,
                screenFrame: screenFrame,
                usesAccessibilityCoordinates: usesAccessibilityCoordinates
            )
            self.setWindow(window, position: nudgeOrigin, size: nudgeSize)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self else { return }
            let finalOrigin = self.settledOrigin(
                for: finalSize,
                targetFrame: CGRect(origin: .zero, size: finalSize),
                side: side,
                screenFrame: screenFrame,
                usesAccessibilityCoordinates: usesAccessibilityCoordinates
            )
            self.setWindow(window, position: finalOrigin, size: finalSize)
        }
    }

    private func nextSnapAnimationToken(for snapKey: String) -> Int {
        let token = (snapAnimationTokens[snapKey] ?? 0) + 1
        snapAnimationTokens[snapKey] = token
        return token
    }

    private func steppedFrames(from currentFrame: CGRect, to targetFrame: CGRect) -> [CGRect] {
        let steps: [CGFloat] = [0.35, 0.7, 1.0]
        return steps.map { progress in
            CGRect(
                x: (currentFrame.minX + (targetFrame.minX - currentFrame.minX) * progress).rounded(.toNearestOrAwayFromZero),
                y: (currentFrame.minY + (targetFrame.minY - currentFrame.minY) * progress).rounded(.toNearestOrAwayFromZero),
                width: max(160, (currentFrame.width + (targetFrame.width - currentFrame.width) * progress).rounded(.toNearestOrAwayFromZero)),
                height: max(120, (currentFrame.height + (targetFrame.height - currentFrame.height) * progress).rounded(.toNearestOrAwayFromZero))
            )
        }
    }

    private func accessibilityScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens
            .map { screen -> (screen: NSScreen, area: CGFloat) in
                let intersection = accessibilityScreenFrame(for: screen).intersection(frame)
                return (screen, intersection.isNull ? 0 : intersection.width * intersection.height)
            }
            .max { $0.area < $1.area }?
            .screen
    }

    private func windowPoint(_ window: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue((axValue as! AXValue), .cgPoint, &point) else { return nil }
        return point
    }

    private func windowSize(_ window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue((axValue as! AXValue), .cgSize, &size) else { return nil }
        return size
    }

    private func preservingRelativeFrame(
        _ windowFrame: CGRect,
        from sourceScreen: NSScreen,
        to targetScreen: NSScreen,
        usesAccessibilityCoordinates: Bool
    ) -> CGRect {
        let source = usesAccessibilityCoordinates
            ? accessibilityScreenFrame(for: sourceScreen)
            : sourceScreen.visibleFrame
        let target = usesAccessibilityCoordinates
            ? accessibilityScreenFrame(for: targetScreen)
            : targetScreen.visibleFrame

        let edgeThreshold: CGFloat = 24
        let verticalEdgeThreshold: CGFloat = usesAccessibilityCoordinates ? 96 : edgeThreshold
        let touchesLeft = abs(windowFrame.minX - source.minX) <= edgeThreshold
        let touchesRight = abs(windowFrame.maxX - source.maxX) <= edgeThreshold
        let touchesBottom = abs(windowFrame.maxY - source.maxY) <= verticalEdgeThreshold
        let touchesTop = abs(windowFrame.minY - source.minY) <= verticalEdgeThreshold

        let relativeMinX = source.width == 0 ? 0 : (windowFrame.minX - source.minX) / source.width
        let relativeMinY = source.height == 0 ? 0 : (windowFrame.minY - source.minY) / source.height
        let relativeWidth = source.width == 0 ? 1 : windowFrame.width / source.width
        let relativeHeight = source.height == 0 ? 1 : windowFrame.height / source.height
        let isHalfWidth = abs(relativeWidth - 0.5) <= 0.08
        let isLeftHalf = touchesLeft && isHalfWidth && !touchesRight
        let isRightHalf = touchesRight && isHalfWidth && !touchesLeft

        let maxWidth = max(160, target.width)
        let maxHeight = max(120, target.height)
        let width: CGFloat
        if touchesLeft && touchesRight {
            width = target.width
        } else if isLeftHalf || isRightHalf {
            width = target.width / 2
        } else {
            width = min(max(160, target.width * relativeWidth), maxWidth)
        }
        let height = touchesTop && touchesBottom
            ? target.height
            : min(max(120, target.height * relativeHeight), maxHeight)

        let rawX: CGFloat
        if touchesLeft {
            rawX = target.minX
        } else if touchesRight {
            rawX = target.maxX - width
        } else {
            rawX = target.minX + target.width * relativeMinX
        }

        let rawY: CGFloat
        if touchesTop {
            rawY = target.minY
        } else if touchesBottom {
            rawY = target.maxY - height
        } else {
            rawY = target.minY + target.height * relativeMinY
        }

        let x = min(max(rawX, target.minX), target.maxX - width)
        let y = min(max(rawY, target.minY), target.maxY - height)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func accessibilityScreenFrame(for screen: NSScreen) -> CGRect {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return CGRect(
                x: screen.visibleFrame.minX,
                y: screen.frame.maxY - screen.visibleFrame.maxY,
                width: screen.visibleFrame.width,
                height: screen.visibleFrame.height
            )
        }

        let displayBounds = CGDisplayBounds(screenNumber)
        let topInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let usableTop = displayBounds.minY + topInset
        let usableBottom = displayBounds.maxY
        let usableHeight = max(120, usableBottom - usableTop)

        return CGRect(
            x: screen.visibleFrame.minX,
            y: usableTop,
            width: screen.visibleFrame.width,
            height: usableHeight
        )
    }

    private func setWindow(_ window: AXUIElement, position: CGPoint, size: CGSize) {
        var mutablePosition = position
        var mutableSize = size

        guard let positionValue = AXValueCreate(.cgPoint, &mutablePosition),
              let sizeValue = AXValueCreate(.cgSize, &mutableSize) else {
            return
        }

        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }

    private func log(_ message: String) {
        let line = "MacSysSettings2: \(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/MacSysSettings2-screen.log")

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
