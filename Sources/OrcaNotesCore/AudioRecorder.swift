import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit

public enum AudioRecorderError: LocalizedError, Equatable {
    case micFailed(String)
    case screenCaptureFailed(String)
    case mixdownFailed(String)
    case fileTooLarge(Int64)
    case noAudioRecorded
    
    public var errorDescription: String? {
        switch self {
        case .micFailed(let msg): return "Microphone capture failed: \(msg)"
        case .screenCaptureFailed(let msg): return "System audio capture failed: \(msg)"
        case .mixdownFailed(let msg): return "Audio mixdown failed: \(msg)"
        case .fileTooLarge(let bytes):
            let mb = Double(bytes) / (1024 * 1024)
            return String(format: "Audio file is too large (%.1f MB). Groq Whisper limit is 25 MB.", mb)
        case .noAudioRecorded: return "No audio was recorded."
        }
    }
}

public final class AudioRecorder: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
    public static let shared = AudioRecorder()
    
    private let audioEngine = AVAudioEngine()
    private var scStream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.orcanotes.audioqueue", qos: .userInitiated)
    
    private var tempMicURL: URL?
    private var tempSysURL: URL?
    private var micAudioFile: AVAudioFile?
    private var sysAudioFile: AVAudioFile?
    
    /// Receives 16 kHz mono samples as they are captured (for live captions).
    public var sampleHandler: (@Sendable (AudioSource, [Float]) -> Void)?

    private func emit(_ source: AudioSource, _ buffer: AVAudioPCMBuffer) {
        guard let handler = sampleHandler, let ch = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
        handler(source, Array(UnsafeBufferPointer(start: ch, count: Int(buffer.frameLength))))
    }

    public private(set) var isRecording = false
    private var recordingStartTime: Date?
    
    public let standardFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)!
    
    public override init() {
        super.init()
    }
    
    public func startRecording() async throws {
        guard !isRecording else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let sessionID = UUID().uuidString
        tempMicURL = tempDir.appendingPathComponent("orca_mic_\(sessionID).caf")
        tempSysURL = tempDir.appendingPathComponent("orca_sys_\(sessionID).caf")
        
        if let micURL = tempMicURL { try? FileManager.default.removeItem(at: micURL) }
        if let sysURL = tempSysURL { try? FileManager.default.removeItem(at: sysURL) }
        
        if let micURL = tempMicURL {
            micAudioFile = try AVAudioFile(forWriting: micURL, settings: standardFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
        
        if let sysURL = tempSysURL {
            sysAudioFile = try AVAudioFile(forWriting: sysURL, settings: standardFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        }
        
        try startMicrophoneCapture()
        
        do {
            try await startSystemAudioCapture()
        } catch {
            print("[OrcaNotes] Warning: System audio capture could not start (\(error.localizedDescription)). Continuing with microphone only.")
        }
        
        isRecording = true
        recordingStartTime = Date()
    }
    
    private func startMicrophoneCapture() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.micFailed("Invalid microphone sample rate.")
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: standardFormat) else {
            throw AudioRecorderError.micFailed("Cannot create microphone audio converter.")
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let micFile = self.micAudioFile else { return }
            
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * (16000.0 / inputFormat.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.standardFormat, frameCapacity: frameCount + 512) else { return }
            
            var error: NSError?
            var inputDelivered = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if !inputDelivered {
                    inputDelivered = true
                    outStatus.pointee = .haveData
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            
            if error == nil && convertedBuffer.frameLength > 0 {
                self.audioQueue.async {
                    try? micFile.write(from: convertedBuffer)
                }
                self.emit(.mic, convertedBuffer)
            }
        }
        
        try audioEngine.start()
    }
    
    private func startSystemAudioCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw AudioRecorderError.screenCaptureFailed("No display found for ScreenCaptureKit.")
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()
        self.scStream = stream
    }
    
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        
        Task { @MainActor in
            guard let sysFile = self.sysAudioFile else { return }
            
            var blockBuffer: CMBlockBuffer?
            var audioBufferList = AudioBufferList()
            let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: &audioBufferList,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: nil,
                blockBufferMemoryAllocator: nil,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            guard status == noErr,
                  let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
                return
            }
            
            let sourceFormat = AVAudioFormat(streamDescription: asbd) ?? self.standardFormat
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, bufferListNoCopy: &audioBufferList) else { return }
            
            if sourceFormat == self.standardFormat {
                try? sysFile.write(from: pcmBuffer)
                self.emit(.system, pcmBuffer)
            } else if let converter = AVAudioConverter(from: sourceFormat, to: self.standardFormat) {
                let frameCount = AVAudioFrameCount(Double(pcmBuffer.frameLength) * (16000.0 / sourceFormat.sampleRate))
                guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.standardFormat, frameCapacity: frameCount + 512) else { return }
                var error: NSError?
                var delivered = false
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    if !delivered {
                        delivered = true
                        outStatus.pointee = .haveData
                        return pcmBuffer
                    } else {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                }
                if error == nil && convertedBuffer.frameLength > 0 {
                    try? sysFile.write(from: convertedBuffer)
                    self.emit(.system, convertedBuffer)
                }
            }
        }
    }
    
    public func stopRecording() async throws -> (outputURL: URL, duration: TimeInterval) {
        guard isRecording else { throw AudioRecorderError.noAudioRecorded }
        isRecording = false
        
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        if let scStream = self.scStream {
            try? await scStream.stopCapture()
            self.scStream = nil
        }
        
        micAudioFile = nil
        sysAudioFile = nil
        
        let finalURL = try mixdownToCompressedAAC()
        return (finalURL, duration)
    }
    
    public static func mixdownBuffers(micURL: URL?, sysURL: URL?, destinationURL: URL) throws -> URL {
        let standardFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)!
        let aacSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000
        ]
        
        try? FileManager.default.removeItem(at: destinationURL)
        let outputAudioFile = try AVAudioFile(forWriting: destinationURL, settings: aacSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        
        let micFile = micURL != nil ? (try? AVAudioFile(forReading: micURL!)) : nil
        let sysFile = sysURL != nil ? (try? AVAudioFile(forReading: sysURL!)) : nil
        
        let chunkSize: AVAudioFrameCount = 4096
        guard let micBuffer = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: chunkSize),
              let sysBuffer = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: chunkSize),
              let mixedBuffer = AVAudioPCMBuffer(pcmFormat: standardFormat, frameCapacity: chunkSize) else {
            throw AudioRecorderError.mixdownFailed("Could not allocate PCM buffers for mixdown.")
        }
        
        let micLength = micFile?.length ?? 0
        let sysLength = sysFile?.length ?? 0
        let maxLength = max(micLength, sysLength)
        
        if maxLength == 0 {
            throw AudioRecorderError.noAudioRecorded
        }
        
        while (outputAudioFile.framePosition < maxLength) {
            var framesToRead = chunkSize
            let remaining = maxLength - outputAudioFile.framePosition
            if remaining < Int64(framesToRead) {
                framesToRead = AVAudioFrameCount(remaining)
            }
            if framesToRead == 0 { break }
            
            var micHasData = false
            if let micFile = micFile, micFile.framePosition < micLength {
                try? micFile.read(into: micBuffer, frameCount: framesToRead)
                micHasData = micBuffer.frameLength > 0
            }
            
            var sysHasData = false
            if let sysFile = sysFile, sysFile.framePosition < sysLength {
                try? sysFile.read(into: sysBuffer, frameCount: framesToRead)
                sysHasData = sysBuffer.frameLength > 0
            }
            
            mixedBuffer.frameLength = framesToRead
            guard let mixedChannel = mixedBuffer.floatChannelData?[0] else { break }
            
            let micChannel = micHasData ? micBuffer.floatChannelData?[0] : nil
            let sysChannel = sysHasData ? sysBuffer.floatChannelData?[0] : nil
            
            for i in 0..<Int(framesToRead) {
                let m = (micChannel != nil && i < Int(micBuffer.frameLength)) ? micChannel![i] : 0.0
                let s = (sysChannel != nil && i < Int(sysBuffer.frameLength)) ? sysChannel![i] : 0.0
                
                var sum = (m + s) * 0.75
                if sum > 1.0 { sum = 1.0 }
                if sum < -1.0 { sum = -1.0 }
                mixedChannel[i] = sum
            }
            
            try outputAudioFile.write(from: mixedBuffer)
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0
        let maxAllowed: Int64 = 25 * 1024 * 1024 // 25 MB
        
        if fileSize > maxAllowed {
            throw AudioRecorderError.fileTooLarge(fileSize)
        }
        
        return destinationURL
    }
    
    private func mixdownToCompressedAAC() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let timestamp = formatter.string(from: recordingStartTime ?? Date())
        let finalURL = Config.shared.notesDirectory.appendingPathComponent("\(timestamp).m4a")
        
        defer {
            if let micURL = tempMicURL { try? FileManager.default.removeItem(at: micURL) }
            if let sysURL = tempSysURL { try? FileManager.default.removeItem(at: sysURL) }
            tempMicURL = nil
            tempSysURL = nil
        }
        
        return try AudioRecorder.mixdownBuffers(micURL: tempMicURL, sysURL: tempSysURL, destinationURL: finalURL)
    }
}
