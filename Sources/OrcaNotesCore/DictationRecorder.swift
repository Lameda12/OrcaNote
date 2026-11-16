import Foundation
@preconcurrency import AVFoundation

/// Lightweight mic-only recorder for dictation (16 kHz mono WAV).
public final class DictationRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var url: URL?
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    public private(set) var isRunning = false
    private var startedAt: Date?

    public init() {}

    public func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, let converter = AVAudioConverter(from: inFormat, to: format) else {
            throw AudioRecorderError.micFailed("No usable input device.")
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("orca_dictation_\(UUID().uuidString).wav")
        file = try AVAudioFile(forWriting: out, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        url = out

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            guard let self, let file = self.file else { return }
            let ratio = self.format.sampleRate / inFormat.sampleRate
            let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
            guard let converted = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: cap) else { return }
            var consumed = false
            var err: NSError?
            converter.convert(to: converted, error: &err) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            if err == nil, converted.frameLength > 0 { try? file.write(from: converted) }
        }
        engine.prepare()
        try engine.start()
        isRunning = true
        startedAt = Date()
    }

    /// Stops capture; returns the file and duration, or nil if nothing useful was recorded.
    public func stop() -> (url: URL, duration: TimeInterval)? {
        guard isRunning else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        file = nil
        let dur = Date().timeIntervalSince(startedAt ?? Date())
        defer { url = nil }
        guard let url, dur >= 0.4 else {
            if let url { try? FileManager.default.removeItem(at: url) }
            return nil
        }
        return (url, dur)
    }
}
