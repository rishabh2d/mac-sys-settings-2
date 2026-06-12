//
//  VoiceBackupController.swift
//  MacSysSettings2
//
//  Created by Codex on 05/28/26.
//

import AppKit
import AVFoundation
import Combine
import Foundation

struct VoiceBackupClip: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let createdAt: Date
    var duration: TimeInterval
    var transcript: String?
    var status: String

    var fileName: String {
        url.lastPathComponent
    }
}

@MainActor
final class VoiceBackupController: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = VoiceBackupController()

    @Published private(set) var clips: [VoiceBackupClip] = []
    @Published private(set) var isRecording = false
    @Published private(set) var lastStatus = "Off"

    let directory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return documents
            .appendingPathComponent("Mac Sys Settings 2", isDirectory: true)
            .appendingPathComponent("Voice Backups", isDirectory: true)
    }()
    private let legacyTemporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MacSysSettings2VoiceBackup", isDirectory: true)
    private var recorder: AVAudioRecorder?
    private var pollingTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    private var folderSource: DispatchSourceFileSystemObject?
    private var folderDescriptor: CInt = -1
    private var sessionStartedAt: Date?
    private var sessionInactiveStartedAt: Date?
    private var quietStartedAt: Date?
    private var isRequestingAudioAccess = false
    private var lastExternalMicSeenAt = Date.distantPast

    override private init() {
        super.init()
    }

    func start() {
        restoreCurrentBootSession()
        startFolderWatcher()
        observeSettingChanges()
        restartPolling()
    }

    deinit {
        pollingTask?.cancel()
        recorder?.stop()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func deleteClip(_ clip: VoiceBackupClip) {
        try? FileManager.default.removeItem(at: clip.url)
        clips.removeAll { $0.id == clip.id }
        lastStatus = "Deleted recording"
    }

    func copyClipFile(_ clip: VoiceBackupClip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([clip.url as NSURL])
        lastStatus = "Copied audio file"
        updateClip(clip.id) { $0.status = "Audio copied" }
    }

    func transcribe(_ clip: VoiceBackupClip) {
        guard let key = VoiceBackupStore.openAIKey() ?? promptForOpenAIKey() else {
            updateClip(clip.id) { $0.status = "OpenAI key needed" }
            return
        }

        updateClip(clip.id) { $0.status = "Transcribing" }
        Task { [weak self] in
            do {
                let text = try await VoiceBackupTranscriber.transcribe(fileURL: clip.url, apiKey: key)
                await MainActor.run {
                    self?.updateClip(clip.id) {
                        $0.transcript = text
                        $0.status = "Transcribed"
                    }
                    self?.lastStatus = "Transcribed recording"
                }
            } catch {
                await MainActor.run {
                    self?.updateClip(clip.id) { $0.status = "Transcription failed" }
                    self?.lastStatus = "Transcription failed"
                }
            }
        }
    }

    func requestOpenAIKey() {
        if promptForOpenAIKey() != nil {
            lastStatus = "OpenAI key saved"
        }
    }

    func reloadFromFolder() {
        restoreCurrentBootSession()
    }

    func revealFolder() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
        lastStatus = "Opened folder"
    }

    private func observeSettingChanges() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: VoiceBackupStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartPolling()
            }
        }
    }

    private func restartPolling() {
        pollingTask?.cancel()
        stopRecording(reason: "Stopped")

        guard VoiceBackupStore.isEnabled else {
            lastStatus = "Off"
            return
        }

        lastStatus = "Watching mic"
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.scan()
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func scan() {
        guard VoiceBackupStore.isEnabled else { return }

        let activeMicNames = AudioInputStore.activeInputDeviceNames()
        let externalMicActive = !activeMicNames.isEmpty
        if externalMicActive, !isRecording {
            lastExternalMicSeenAt = Date()
            sessionInactiveStartedAt = nil
            startRecordingIfNeeded()
        }

        guard isRecording, let recorder else {
            lastStatus = externalMicActive ? "Mic active" : "Watching mic"
            return
        }

        let now = Date()
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)

        if externalMicActive {
            quietStartedAt = nil
            sessionInactiveStartedAt = nil
        } else {
            sessionInactiveStartedAt = sessionInactiveStartedAt ?? now
        }

        if level < -52 {
            quietStartedAt = quietStartedAt ?? now
        } else {
            quietStartedAt = nil
        }

        let micTurnedOff = sessionInactiveStartedAt.map { now.timeIntervalSince($0) > 0.7 } ?? false
        let silentTail = quietStartedAt.map { now.timeIntervalSince($0) > 5.0 } ?? false
        let reachedMaximumLength = sessionStartedAt.map { now.timeIntervalSince($0) > 600 } ?? false
        if micTurnedOff || silentTail || reachedMaximumLength {
            stopRecording(reason: reachedMaximumLength ? "Saved max length" : "Saved mic session")
        }
    }

    private func startRecordingIfNeeded() {
        guard !isRecording, !isRequestingAudioAccess else { return }
        isRequestingAudioAccess = true
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.isRequestingAudioAccess = false
                guard granted else {
                    self.lastStatus = "Microphone permission needed"
                    return
                }
                self.startRecorder()
            }
        }
    }

    private func startRecorder() {
        guard !isRecording else { return }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Voice Backup \(Self.fileDateFormatter.string(from: Date())).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                lastStatus = "Could not start recording"
                return
            }

            self.recorder = recorder
            isRecording = true
            sessionStartedAt = Date()
            sessionInactiveStartedAt = nil
            quietStartedAt = nil
            lastStatus = "Backing up voice"
        } catch {
            lastStatus = "Recording failed"
        }
    }

    private func stopRecording(reason: String) {
        guard let recorder else { return }
        let url = recorder.url
        let duration = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        isRecording = false
        sessionStartedAt = nil
        sessionInactiveStartedAt = nil
        quietStartedAt = nil

        guard duration >= 0.8, FileManager.default.fileExists(atPath: url.path) else {
            try? FileManager.default.removeItem(at: url)
            lastStatus = "Ignored tiny recording"
            return
        }

        clips.insert(VoiceBackupClip(id: UUID(), url: url, createdAt: Date(), duration: duration, transcript: nil, status: reason), at: 0)
        trimClips()
        lastStatus = reason
    }

    private func trimClips() {
        let files = currentBackupFiles()
        for file in files.dropFirst(3) {
            try? FileManager.default.removeItem(at: file.url)
        }
        clips = clips
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { $0 }
    }

    private func restoreCurrentBootSession() {
        migrateLegacyTemporaryFiles()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bootDate = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)

        var restoredClips: [VoiceBackupClip] = []
        for item in currentBackupFiles() {
            if isRecording, item.url == recorder?.url {
                continue
            }

            let createdAt = item.createdAt
            guard createdAt >= bootDate else {
                try? FileManager.default.removeItem(at: item.url)
                continue
            }

            restoredClips.append(VoiceBackupClip(
                id: UUID(),
                url: item.url,
                createdAt: createdAt,
                duration: Self.duration(for: item.url),
                transcript: nil,
                status: "Saved"
            ))
        }

        clips = restoredClips.sorted { $0.createdAt > $1.createdAt }
        trimClips()
    }

    private func currentBackupFiles() -> [(url: URL, createdAt: Date)] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return files
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .map { file in
                let values = try? file.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                let fallbackDate = (try? FileManager.default.attributesOfItem(atPath: file.path)[.creationDate] as? Date) ?? Date.distantPast
                return (file, values?.creationDate ?? values?.contentModificationDate ?? fallbackDate)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func migrateLegacyTemporaryFiles() {
        guard FileManager.default.fileExists(atPath: legacyTemporaryDirectory.path) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let legacyFiles = (try? FileManager.default.contentsOfDirectory(
            at: legacyTemporaryDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for file in legacyFiles where file.pathExtension.lowercased() == "m4a" {
            let destination = directory.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: file)
            } else {
                try? FileManager.default.moveItem(at: file, to: destination)
            }
        }

        try? FileManager.default.removeItem(at: legacyTemporaryDirectory)
    }

    private func startFolderWatcher() {
        stopFolderWatcher()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        folderDescriptor = open(directory.path, O_EVTONLY)
        guard folderDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: folderDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.restoreCurrentBootSession()
            }
        }
        source.setCancelHandler { [folderDescriptor] in
            if folderDescriptor >= 0 {
                close(folderDescriptor)
            }
        }
        folderSource = source
        source.resume()
    }

    private func stopFolderWatcher() {
        folderSource?.cancel()
        folderSource = nil
        folderDescriptor = -1
    }

    private func updateClip(_ id: UUID, update: (inout VoiceBackupClip) -> Void) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        update(&clips[index])
    }

    private func promptForOpenAIKey() -> String? {
        let alert = NSAlert()
        alert.messageText = "Connect OpenAI key"
        alert.informativeText = "Voice Backup only transcribes when you ask. Paste an OpenAI API key to transcribe this recording."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save Key")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "sk-..."
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn,
              VoiceBackupStore.saveOpenAIKey(field.stringValue) else {
            return nil
        }

        return VoiceBackupStore.openAIKey()
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    private static func duration(for url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}

private enum VoiceBackupTranscriber {
    static func transcribe(fileURL: URL, apiKey: String) async throws -> String {
        let boundary = "MacSysSettings2Boundary\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(fileURL: fileURL, boundary: boundary)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func multipartBody(fileURL: URL, boundary: String) throws -> Data {
        var data = Data()
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        data.appendString("gpt-4o-mini-transcribe\r\n")
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        data.appendString("Content-Type: audio/mp4\r\n\r\n")
        data.append(try Data(contentsOf: fileURL))
        data.appendString("\r\n--\(boundary)--\r\n")
        return data
    }

    private struct TranscriptionResponse: Decodable {
        let text: String
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
