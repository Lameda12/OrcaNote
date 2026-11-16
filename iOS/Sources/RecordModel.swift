import Foundation
import UIKit
import OrcaShared

enum RecordMode: String, CaseIterable, Identifiable {
    case meeting = "Meeting", dictate = "Dictate"
    var id: String { rawValue }
}

@MainActor
final class RecordModel: ObservableObject {
    @Published var mode: RecordMode = .meeting
    @Published var isRecording = false
    @Published var elapsed = 0
    @Published var busy: String?
    @Published var error: String?
    @Published var dictation = ""
    @Published var style: WritingStyle = Preferences.defaultStyle
    @Published var savedNote: Note?

    private var timer: Timer?
    private var base = ""

    var timerText: String { String(format: "%02d:%02d", elapsed / 60, elapsed % 60) }

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        error = nil
        dictation = ""
        Task {
            guard await PhoneRecorder.requestPermission() else {
                error = "Microphone access is off. Enable it in Settings → Privacy → Microphone."
                return
            }
            base = NotesStore.shared.newBaseName()
            let out: URL = mode == .meeting
                ? NotesStore.shared.directory.appendingPathComponent("\(base).m4a")
                : FileManager.default.temporaryDirectory.appendingPathComponent("dictation-\(base).m4a")
            do {
                if mode == .meeting {
                    LiveCaptioner.shared.start()
                    PhoneRecorder.shared.sampleHandler = { samples in
                        Task { @MainActor in LiveCaptioner.shared.append(.mic, samples) }
                    }
                } else {
                    PhoneRecorder.shared.sampleHandler = nil
                }
                PhoneRecorder.shared.onInterruption = { [weak self] in self?.stop() }
                try PhoneRecorder.shared.start(to: out)
                LocalTranscriber.shared.prepare()
                isRecording = true
                elapsed = 0
                UIApplication.shared.isIdleTimerDisabled = true
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.elapsed += 1 }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        isRecording = false
        PhoneRecorder.shared.sampleHandler = nil
        guard let rec = PhoneRecorder.shared.stop() else { return }
        let mode = self.mode
        Task {
            do {
                if mode == .meeting { try await finishMeeting(rec.url, rec.duration) }
                else { try await finishDictation(rec.url) }
            } catch {
                self.error = error.localizedDescription
            }
            busy = nil
        }
    }

    private func finishMeeting(_ url: URL, _ duration: TimeInterval) async throws {
        busy = "Finishing captions…"
        let speakers = await LiveCaptioner.shared.finish()
        busy = "Transcribing on this device…"
        let transcript = try await LocalTranscriber.shared.transcribe(audioURL: url)
        guard !transcript.isEmpty else { throw PipelineError.transcriptionFailed("No speech detected.") }
        busy = Preferences.aiProvider == .off ? "Saving…" : "Writing summary…"
        let summary = await Summarizer.summarize(transcript: transcript)
        let noteURL = try NotesStore.shared.save(base: base, audioURL: url, duration: duration,
                                                 summary: summary, transcript: transcript, speakerTranscript: speakers)
        savedNote = NotesStore.shared.notes.first { $0.url == noteURL }
    }

    private func finishDictation(_ url: URL) async throws {
        defer { try? FileManager.default.removeItem(at: url) }
        busy = "Transcribing…"
        let raw = try await LocalTranscriber.shared.transcribe(audioURL: url)
        busy = "Cleaning up…"
        dictation = await DictationPolish.polish(raw, style: style)
        if !dictation.isEmpty { UIPasteboard.general.string = dictation }
    }
}

/// Same rules as the Mac app: offline cleanup, optional AI rewrite.
enum DictationPolish {
    static func polish(_ raw: String, style: WritingStyle) async -> String {
        let local = TextCleanup.clean(raw, style: style)
        guard style != .verbatim, Preferences.aiPolish, Preferences.aiProvider != .off else { return local }
        let system = "You edit dictated text. \(style.llmInstruction) Output only the edited text, with no preamble or commentary."
        guard let out = try? await LLMClient.chat(system: system, user: local, timeout: 15, maxTokens: 512),
              LLMClient.acceptPolish(original: local, output: out) else { return local }
        return out
    }
}
