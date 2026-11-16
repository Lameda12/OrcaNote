import Foundation
import SwiftUI
import AppKit
import AVFoundation
import CoreGraphics

public struct NoteItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let dateStr: String
    public let fileURL: URL
    public let audioURL: URL?
    
    public init(title: String, dateStr: String, fileURL: URL, audioURL: URL?) {
        self.title = title
        self.dateStr = dateStr
        self.fileURL = fileURL
        self.audioURL = audioURL
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var isRecording = false
    @Published public var elapsedSeconds = 0
    @Published public var statusMessage = "Ready for meeting"
    @Published public var isProcessing = false
    @Published public var hasApiKey = false
    @Published public var apiKeyInput = ""
    @Published public var isShowingSettings = false
    @Published public var recentNotes: [NoteItem] = []
    
    @Published public var micPermission = true
    @Published public var screenPermission = true
    
    private var timer: Timer?
    
    public init() {
        self.hasApiKey = (Config.shared.groqApiKey != nil && !Config.shared.groqApiKey!.isEmpty)
        checkPermissions()
        refreshRecentNotes()
    }
    
    public var formattedTimer: String {
        let mins = String(format: "%02d", elapsedSeconds / 60)
        let secs = String(format: "%02d", elapsedSeconds % 60)
        return "\(mins):\(secs)"
    }
    
    public func checkPermissions() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        self.micPermission = (micStatus == .authorized || micStatus == .notDetermined)
        
        if #available(macOS 11.0, *) {
            self.screenPermission = CGPreflightScreenCaptureAccess()
        }
    }
    
    public func requestScreenPermission() {
        if #available(macOS 11.0, *) {
            CGRequestScreenCaptureAccess()
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                self.micPermission = granted
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Config.shared.saveGroqApiKey(trimmed)
        self.hasApiKey = true
        self.apiKeyInput = ""
        self.isShowingSettings = false
        self.statusMessage = "API Key saved! Ready to record."
    }
    
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    public func startRecording() {
        guard hasApiKey || Preferences.useLocalSTT else {
            self.isShowingSettings = true
            self.statusMessage = "Turn on on-device transcription or add a Groq key."
            return
        }
        
        Task {
            do {
                try await AudioRecorder.shared.startRecording()
                self.isRecording = true
                LiveCaptioner.shared.start()
                AudioRecorder.shared.sampleHandler = { source, samples in
                    Task { @MainActor in LiveCaptioner.shared.append(source, samples) }
                }
                self.elapsedSeconds = 0
                self.statusMessage = "Recording meeting audio (System + Mic)..."
                
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self, self.isRecording else { return }
                        self.elapsedSeconds += 1
                    }
                }
            } catch {
                self.statusMessage = "Recording error: \(error.localizedDescription)"
            }
        }
    }
    
    public func stopRecording() {
        self.timer?.invalidate()
        self.timer = nil
        self.isRecording = false
        self.isProcessing = true
        self.statusMessage = Preferences.useLocalSTT ? "Mixing audio & transcribing on this Mac..." : "Mixing audio & transcribing with Groq..."
        
        Task {
            do {
                let (audioURL, duration) = try await AudioRecorder.shared.stopRecording()
                AudioRecorder.shared.sampleHandler = nil
                let speakerTranscript = await LiveCaptioner.shared.finish()
                self.statusMessage = {
                    switch Preferences.aiProvider {
                    case .local, .apple: return "Summarizing on this Mac…"
                    case .groq: return "Summarizing with Groq…"
                    case .off: return "Saving note…"
                    }
                }()
                
                let noteURL = try await MeetingPipeline.shared.processMeeting(audioURL: audioURL, duration: duration, speakerTranscript: speakerTranscript)
                
                self.isProcessing = false
                self.statusMessage = "✓ Note saved to ~/MeetingNotes!"
                self.refreshRecentNotes()
                
                NSWorkspace.shared.open(noteURL)
            } catch {
                self.isProcessing = false
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    public func refreshRecentNotes() {
        let dir = Config.shared.notesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return
        }
        
        let mdFiles = files.filter { $0.pathExtension == "md" }
            .sorted { (u1, u2) -> Bool in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 > d2
            }
        
        self.recentNotes = mdFiles.prefix(5).map { url in
            let base = url.deletingPathExtension().lastPathComponent
            let audioURL = dir.appendingPathComponent("\(base).m4a")
            return NoteItem(
                title: base,
                dateStr: base,
                fileURL: url,
                audioURL: FileManager.default.fileExists(atPath: audioURL.path) ? audioURL : nil
            )
        }
    }
    
    public func openNote(_ note: NoteItem) {
        NSWorkspace.shared.open(note.fileURL)
    }
    
    public func openNotesFolder() {
        NSWorkspace.shared.open(Config.shared.notesDirectory)
    }
}
