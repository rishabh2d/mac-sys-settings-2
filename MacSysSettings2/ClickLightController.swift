//
//  ClickLightController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/25/26.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ClickLightController: ObservableObject {
    static let shared = ClickLightController()

    @Published private(set) var lastStatus = "Ready"

    private let presenter = ClickLightPresenter()
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var cursorTimer: Timer?
    private var observer: NSObjectProtocol?
    private var lastDragPulse = Date.distantPast
    private var lastPulseDate = Date.distantPast
    private var lastPulsePoint = CGPoint.zero
    private var lastPulseKind: ClickLightKind?

    func start() {
        observeChanges()
        reloadTap()
    }

    func testPulse() {
        presenter.show(kind: .press, at: NSEvent.mouseLocation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.presenter.show(kind: .release, at: NSEvent.mouseLocation)
        }
        lastStatus = "Test pulse"
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        cursorTimer?.invalidate()
    }

    private func observeChanges() {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: ClickLightStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let controller = self else { return }
            Task { @MainActor in
                controller.reloadTap()
            }
        }
    }

    private func reloadTap() {
        stopTap()
        stopMouseMonitors()
        stopCursorTimer()

        guard ClickLightStore.isEnabled else {
            presenter.hideCursorHighlight()
            lastStatus = "Off"
            return
        }

        startCursorTimer()
        startMouseMonitors()

        guard AXIsProcessTrusted() else {
            lastStatus = "Watching clicks"
            return
        }

        let mask =
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDragged.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<ClickLightController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = controller.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            Task { @MainActor in
                controller.handle(eventType: type, location: NSEvent.mouseLocation)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPointer
        ) else {
            lastStatus = "Could not watch clicks"
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        lastStatus = "Watching clicks"
    }

    private func stopTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
    }

    private func startMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged
        ]

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(mouseEvent: event)
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in
                self?.handle(mouseEvent: event)
            }
            return event
        }
    }

    private func stopMouseMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func startCursorTimer() {
        cursorTimer?.invalidate()
        presenter.updateCursorHighlight(at: NSEvent.mouseLocation)
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard ClickLightStore.isEnabled else {
                    self?.stopCursorTimer()
                    self?.presenter.hideCursorHighlight()
                    return
                }
                self?.presenter.updateCursorHighlight(at: NSEvent.mouseLocation)
            }
        }
        cursorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopCursorTimer() {
        cursorTimer?.invalidate()
        cursorTimer = nil
    }

    private func handle(mouseEvent event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            show(kind: .press, at: NSEvent.mouseLocation, status: "Click")
        case .leftMouseUp:
            show(kind: .release, at: NSEvent.mouseLocation, status: "Release")
        case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            show(kind: .rightClick, at: NSEvent.mouseLocation, status: "Right click")
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let now = Date()
            guard now.timeIntervalSince(lastDragPulse) > 0.12 else { return }
            lastDragPulse = now
            show(kind: .drag, at: NSEvent.mouseLocation, status: "Drag")
        default:
            break
        }
    }

    private func handle(eventType: CGEventType, location: CGPoint) {
        guard ClickLightStore.isEnabled else { return }

        switch eventType {
        case .leftMouseDown:
            show(kind: .press, at: location, status: "Click")
        case .leftMouseUp:
            show(kind: .release, at: location, status: "Release")
        case .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            show(kind: .rightClick, at: location, status: "Right click")
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let now = Date()
            guard now.timeIntervalSince(lastDragPulse) > 0.12 else { return }
            lastDragPulse = now
            show(kind: .drag, at: location, status: "Drag")
        default:
            break
        }
    }

    private func show(kind: ClickLightKind, at point: CGPoint, status: String) {
        let now = Date()
        if lastPulseKind == kind,
           now.timeIntervalSince(lastPulseDate) < 0.04,
           hypot(point.x - lastPulsePoint.x, point.y - lastPulsePoint.y) < 4 {
            return
        }

        lastPulseKind = kind
        lastPulseDate = now
        lastPulsePoint = point
        presenter.show(kind: kind, at: point)
        lastStatus = status
    }
}
