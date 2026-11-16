import Foundation
@preconcurrency import AVFoundation
import OrcaShared

/// Microphone recorder for iPhone/iPad: writes AAC .m4a and streams 16 kHz samples for live captions.
final class PhoneRecorder: @unchecked Sendable {
    static let shared = PhoneRecorder()

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var url: URL?
    private(set) var isRunning = false
    private var startedAt: Date?
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    /// Called on the audio thread with converted samples.
    var sampleHandler: (@Sendable ([Float]) -> Void)?
    /// Called on the main queue when the system interrupts recording (phone call, Siri).
    var onInterruption: (() -> Void)?

    private init() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began, self?.isRunning == true else { return }
            self?.onInterruption?()
        }
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(to output: URL) throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, let converter = AVAudioConverter(from: inFormat, to: format) else {
            throw NSError(domain: "OrcaNotes", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone available."])
        }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                       AVSampleRateKey: 16000,
                                       AVNumberOfChannelsKey: 1,
                                       AVEncoderBitRateKey: 32000]
        file = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        url = output

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            guard let self, let file = self.file else { return }
            let cap = AVAudioFrameCount(Double(buffer.frameLength) * 16000 / inFormat.sampleRate) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: cap) else { return }
            var given = false
            var err: NSError?
            converter.convert(to: out, error: &err) { _, status in
                if given { status.pointee = .noDataNow; return nil }
                given = true; status.pointee = .haveData; return buffer
            }
            guard err == nil, out.frameLength > 0 else { return }
            try? file.write(from: out)
            if let h = self.sampleHandler, let ch = out.floatChannelData?[0] {
                h(Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength))))
            }
        }
        engine.prepare()
        try engine.start()
        isRunning = true
        startedAt = Date()
    }

    /// Stops and returns the recording and its duration.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard isRunning else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        file = nil // closes and finalizes the m4a
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let duration = Date().timeIntervalSince(startedAt ?? Date())
        guard let url else { return nil }
        self.url = nil
        return (url, duration)
    }
}
