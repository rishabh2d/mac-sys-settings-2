//
//  MuteKeyMonitor.swift
//  MacSysSettings2
//
//  Created by Codex on 07/04/26.
//

import AppKit
import Foundation
import IOKit.hidsystem

@MainActor
final class MuteKeyMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var onMuteChanged: ((Bool) -> Void)?
    private var isMuted = false

    func start(initialMutedState: Bool, onMuteChanged: @escaping (Bool) -> Void) {
        guard localMonitor == nil, globalMonitor == nil else { return }

        self.isMuted = initialMutedState
        self.onMuteChanged = onMuteChanged

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.systemDefined]) { [weak self] event in
            self?.handle(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.systemDefined]) { [weak self] event in
            self?.handle(event)
        }

        print("MacSysSettings2: mute key monitor started. initialMutedState=\(initialMutedState)")
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        onMuteChanged = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return }

        let keyCode = Int32((event.data1 & 0xFFFF0000) >> 16)
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0xA
        let isRepeat = (keyFlags & 0x1) == 0x1

        guard keyCode == NX_KEYTYPE_MUTE, isKeyDown, !isRepeat else { return }

        isMuted.toggle()
        print("MacSysSettings2: mute key pressed. interpretedMutedState=\(isMuted)")
        onMuteChanged?(isMuted)
    }
}
