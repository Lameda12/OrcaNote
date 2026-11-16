import AppKit
import Carbon.HIToolbox

public enum DictationPhase: Equatable {
    case idle, listening, transcribing, done(String), failed(String)
}

/// Push-to-talk dictation: hold ⌃⌥Space to talk, release to insert. A quick tap toggles instead.
@MainActor
public final class DictationController: ObservableObject {
    public static let shared = DictationController()

    @Published public private(set) var phase: DictationPhase = .idle

    private let recorder = DictationRecorder()
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var pressedAt: Date?
    private var targetBundleID: String?
    private var latched = false

    public init() {}

    public func registerHotKey() {
        guard hotKeyRef == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            let kind = GetEventKind(event)
            Task { @MainActor in
                if kind == UInt32(kEventHotKeyPressed) { DictationController.shared.keyDown() }
                else { DictationController.shared.keyUp() }
            }
            return noErr
        }, 2, &specs, nil, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x4F524341), id: 1) // 'ORCA'
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func keyDown() {
        guard Preferences.dictationEnabled else { return }
        if latched { finish(); return }
        guard phase == .idle || isTerminal(phase) else { return }
        // Capture the target app before any of our UI can take focus.
        targetBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        pressedAt = Date()
        do {
            try recorder.start()
            phase = .listening
            if Preferences.useLocalSTT { LocalTranscriber.shared.prepare() }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func keyUp() {
        guard phase == .listening, let pressedAt else { return }
        if Date().timeIntervalSince(pressedAt) < 0.35 {
            latched = true // quick tap: keep listening until next press
        } else {
            finish()
        }
    }

    private func isTerminal(_ p: DictationPhase) -> Bool {
        switch p { case .done, .failed: return true; default: return false }
    }

    private func finish() {
        latched = false
        guard let rec = recorder.stop() else { phase = .idle; return }
        phase = .transcribing
        let bundleID = targetBundleID
        Task {
            defer { try? FileManager.default.removeItem(at: rec.url) }
            do {
                let raw = try await Transcriber.transcribe(audioURL: rec.url)
                guard !raw.isEmpty else { phase = .idle; return }
                let style = Preferences.styleRules.style(forBundleID: bundleID)
                let text = await DictationPipeline.polish(raw, style: style)
                let inserted = await TextInserter.insert(text)
                if !inserted { TextInserter.requestAccessibility() }
                phase = inserted ? .done(text) : .failed("Copied to clipboard — grant Accessibility to auto-paste.")
            } catch {
                phase = .failed(error.localizedDescription)
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if isTerminal(phase) { phase = .idle }
        }
    }
}

public enum DictationPipeline {
    /// Offline rules always; optional AI rewrite (local Ollama or Groq) when the user turns on AI polish.
    public static func polish(_ raw: String, style: WritingStyle) async -> String {
        let local = TextCleanup.clean(raw, style: style)
        guard style != .verbatim, Preferences.aiPolish, Preferences.aiProvider != .off else { return local }
        let system = "You edit dictated text. \(style.llmInstruction) Output only the edited text, with no preamble or commentary."
        guard let out = try? await LLMClient.chat(system: system, user: local, timeout: 15, maxTokens: 512),
              LLMClient.acceptPolish(original: local, output: out) else { return local }
        return out
    }
}

/// Routes audio to local WhisperKit, falling back to Groq when a key exists.
public enum Transcriber {
    public static func transcribe(audioURL: URL) async throws -> String {
        let key = Config.shared.groqApiKey
        if Preferences.useLocalSTT {
            do { return try await LocalTranscriber.shared.transcribe(audioURL: audioURL) }
            catch {
                guard let key else { throw error }
                return try await MeetingPipeline.shared.transcribeWithGroq(audioURL: audioURL, apiKey: key)
            }
        }
        guard let key else { throw PipelineError.apiKeyMissing }
        return try await MeetingPipeline.shared.transcribeWithGroq(audioURL: audioURL, apiKey: key)
    }
}
