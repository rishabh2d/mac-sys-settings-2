//
//  AudioInputStore.swift
//  MacSysSettings2
//
//  Created by Codex on 05/18/26.
//

import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let name: String
}

enum AudioInputStore {
    static func inputDevices() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = Array(repeating: AudioObjectID(0), count: count)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }

        return ids.compactMap { id in
            guard hasInputStreams(deviceID: id), let name = deviceName(deviceID: id) else { return nil }
            return AudioInputDevice(id: id, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func defaultInputDevice() -> AudioInputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(0)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID) == noErr,
              let name = deviceName(deviceID: deviceID) else {
            return nil
        }

        return AudioInputDevice(id: deviceID, name: name)
    }

    @discardableResult
    static func setDefaultInputDevice(_ device: AudioInputDevice) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = device.id
        let dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, dataSize, &deviceID) == noErr
    }

    private static func hasInputStreams(deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr && dataSize > 0
    }

    private static func deviceName(deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name) == noErr else {
            return nil
        }

        let trimmed = (name as String).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
