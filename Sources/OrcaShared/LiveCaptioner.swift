import Foundation

public struct CaptionLine: Identifiable, Equatable {
    public let id = UUID()
    public let speaker: String   // "You" (mic) or "Them" (system audio)
    public let text: String
    public let offset: TimeInterval
}

/// Pure helpers, kept separate so they can be unit tested.
public enum CaptionLogic {
    public static func rms(_ s: ArraySlice<Float>) -> Float {
        guard !s.isEmpty else { return 0 }
        return (s.reduce(0) { $0 + $1 * $1 } / Float(s.count)).squareRoot()
    }

    /// Whisper invents text on near-silence; drop the usual junk.
    public static func isNoise(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        if t.isEmpty { return true }
        if text.hasPrefix("[") || text.hasPrefix("(") { return true }
        return ["thank you", "thanks for watching", "you", "bye"].contains(t)
    }

    static func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    /// True when `a` mostly repeats `b` (mic picking up the speakers).
    public static func isEcho(_ a: String, of b: String) -> Bool {
        let wa = words(a), wb = words(b)
        guard wa.count >= 3, !wb.isEmpty else { return false }
        return Double(wa.intersection(wb).count) / Double(wa.count) >= 0.7
    }

    /// Removes Whisper's non-speech tags such as [silence], [BLANK_AUDIO], (music).
    public static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[[^\]]*\]|\((?i:[^)]*(?:silence|music|blank|noise|inaudible|laugh|applause|cough|sigh|breath|muffled|speaking|talking|indistinct|chatter|crosstalk|static|sniff)[^)]*)\)"#,
                                  with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Minimum level that can count as speech, whatever the room.
    public static let absoluteSpeechFloor: Float = 0.0015

    /// Tracks background noise: drops quickly to quieter levels, rises slowly so speech doesn't inflate it.
    public static func updateNoiseFloor(_ floor: Float, blockRMS r: Float) -> Float {
        guard r > 0 else { return floor }
        return r < floor ? r : floor * 0.995 + r * 0.005
    }

    /// Speech must be well above the room's noise floor (adapts to quiet and loud mics).
    public static func speechThreshold(noiseFloor: Float) -> Float {
        max(absoluteSpeechFloor, noiseFloor * 3)
    }

    /// Markdown transcript with speaker labels.
    /// Speaker labels are only shown when there is more than one source (e.g. You and Them on a Mac call).
    public static func markdown(_ lines: [CaptionLine]) -> String {
        let labelled = Set(lines.map(\.speaker)).count > 1
        return lines.map { l in
            let m = Int(l.offset) / 60, sec = Int(l.offset) % 60
            let stamp = String(format: "[%02d:%02d]", m, sec)
            return labelled ? "**\(l.speaker)** \(stamp): \(l.text)" : "\(stamp) \(l.text)"
        }.joined(separator: "\n\n")
    }
}

/// Chunks live audio per source, transcribes speech chunks on-device, and publishes captions.
/// "You" = microphone, "Them" = system audio (the other people on the call).
@MainActor
public final class LiveCaptioner: ObservableObject {
    public static let shared = LiveCaptioner()

    @Published public private(set) var lines: [CaptionLine] = []
    @Published public private(set) var isActive = false

    private let rate = 16000
    private let minChunk = 3 * 16000, maxChunk = 12 * 16000, tail = 9600 // 0.6 s
    private var noiseFloor: [AudioSource: Float] = [:]
    private var buffers: [AudioSource: [Float]] = [.mic: [], .system: []]
    private var consumed: [AudioSource: Int] = [.mic: 0, .system: 0]
    private var chain: Task<Void, Never>?
    private var startedAt = Date()

    public init() {}

    public func start() {
        lines = []
        buffers = [.mic: [], .system: []]
        consumed = [.mic: 0, .system: 0]
        noiseFloor = [.mic: 0.001, .system: 0.001]
        startedAt = Date()
        isActive = Preferences.useLocalSTT
        guard isActive else { return }
        LocalTranscriber.shared.prepare()
    }

    /// Feed 16 kHz mono samples from any recorder.
    public func append(_ source: AudioSource, _ samples: [Float]) {
        guard isActive else { return }
        buffers[source, default: []].append(contentsOf: samples)
        noiseFloor[source] = CaptionLogic.updateNoiseFloor(noiseFloor[source] ?? 0.001, blockRMS: CaptionLogic.rms(samples[...]))
        let buf = buffers[source]!
        guard buf.count >= minChunk else { return }
        let quietTail = CaptionLogic.rms(buf.suffix(tail)) < threshold(source)
        if quietTail || buf.count >= maxChunk { flush(source) }
    }

    private func flush(_ source: AudioSource) {
        let chunk = buffers[source] ?? []
        buffers[source] = []
        let offset = TimeInterval(consumed[source] ?? 0) / TimeInterval(rate)
        consumed[source, default: 0] += chunk.count
        guard hasSpeech(chunk, threshold(source)) else { return }

        let previous = chain
        chain = Task { [weak self] in
            await previous?.value
            let text = await LocalTranscriber.shared.transcribe(samples: chunk)
            await MainActor.run { self?.add(source, text, offset) }
        }
    }

    private func threshold(_ source: AudioSource) -> Float {
        CaptionLogic.speechThreshold(noiseFloor: noiseFloor[source] ?? 0.001)
    }

    /// True when the loudest 10% of 100 ms frames clear the speech threshold.
    private func hasSpeech(_ chunk: [Float], _ threshold: Float) -> Bool {
        guard !chunk.isEmpty else { return false }
        let frames = stride(from: 0, to: chunk.count, by: 1600).map { CaptionLogic.rms(chunk[$0..<min($0 + 1600, chunk.count)]) }.sorted()
        return frames[Int(Double(frames.count - 1) * 0.9)] >= threshold
    }

    private func add(_ source: AudioSource, _ text: String, _ offset: TimeInterval) {
        guard !CaptionLogic.isNoise(text) else { return }
        if source == .mic,
           lines.suffix(4).contains(where: { $0.speaker == "Them" && CaptionLogic.isEcho(text, of: $0.text) }) { return }
        lines.append(CaptionLine(speaker: source == .mic ? "You" : "Them", text: text, offset: offset))
        lines.sort { $0.offset < $1.offset }
    }

    /// Flushes remaining audio, waits for pending work, returns the speaker transcript (nil if empty).
    public func finish() async -> String? {
        guard isActive else { return nil }
        flush(.mic); flush(.system)
        await chain?.value
        isActive = false
        return lines.isEmpty ? nil : CaptionLogic.markdown(lines)
    }
}
