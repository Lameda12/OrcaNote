import XCTest
import AVFoundation
@testable import OrcaNotesCore

final class OrcaNotesTests: XCTestCase {
    
    // 1. Test .env file parser
    func testEnvParser() {
        let sampleEnv = """
        # This is a comment
        GROQ_API_KEY=gsk_test_key_12345
        NOTES_DIRECTORY="~/CustomMeetingNotes"
        EMPTY_VAR=
        """
        
        let parsed = Config.parseEnvString(sampleEnv)
        XCTAssertEqual(parsed["GROQ_API_KEY"], "gsk_test_key_12345")
        XCTAssertEqual(parsed["NOTES_DIRECTORY"], "~/CustomMeetingNotes")
        XCTAssertNil(parsed["NON_EXISTENT"])
    }
    
    // 2. Test Markdown note formatting
    func testMarkdownDocumentFormatting() {
        let summary = """
        ## Executive Summary
        - Milestone 1 agreed upon.
        - Discussed architecture roadmap.
        - Validated sub-2s Groq transcription.
        - Fixed Gatekeeper friction.
        - Set weekend ship deadline.
        
        ## Decisions Made
        - All audio encoded as AAC mono .m4a.
        - Direct local storage in ~/MeetingNotes.
        
        ## Action Items
        - [ ] **Alex**: Deploy landing page.
        - [ ] **Sarah**: Run TestFlight build.
        """
        
        let transcript = "[00:00] Alex: Hello team, let's review the notes."
        
        let formatted = MeetingPipeline.formatMarkdownDocument(
            dateStr: "2026-08-23",
            timeStr: "18:30",
            durationStr: "12m 45s",
            audioFileName: "2026-08-23-1830.m4a",
            audioFilePath: "/Users/test/MeetingNotes/2026-08-23-1830.m4a",
            summaryMarkdown: summary,
            transcript: transcript
        )
        
        XCTAssertTrue(formatted.contains("# Meeting Notes — 2026-08-23 18:30"))
        XCTAssertTrue(formatted.contains("**Duration:** 12m 45s"))
        XCTAssertTrue(formatted.contains("## Executive Summary"))
        XCTAssertTrue(formatted.contains("## Decisions Made"))
        XCTAssertTrue(formatted.contains("## Action Items"))
        XCTAssertTrue(formatted.contains("---"))
        XCTAssertTrue(formatted.contains("## Full Transcript"))
        XCTAssertTrue(formatted.contains(transcript))
    }
    
    // 3. Test Audio Mixdown & AAC Compression Pipeline
    func testAudioMixdownAndAACEncoding() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let micURL = tempDir.appendingPathComponent("test_mic_\(UUID().uuidString).caf")
        let sysURL = tempDir.appendingPathComponent("test_sys_\(UUID().uuidString).caf")
        let outM4AURL = tempDir.appendingPathComponent("test_out_\(UUID().uuidString).m4a")
        
        defer {
            try? FileManager.default.removeItem(at: micURL)
            try? FileManager.default.removeItem(at: sysURL)
            try? FileManager.default.removeItem(at: outM4AURL)
        }
        
        let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000.0, channels: 1, interleaved: false)!
        
        // Write 1 second of synthetic audio to mic
        let micFile = try AVAudioFile(forWriting: micURL, settings: pcmFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let micBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 16000) else {
            XCTFail("Failed to create mic PCM buffer")
            return
        }
        micBuffer.frameLength = 16000
        let micChannel = micBuffer.floatChannelData![0]
        for i in 0..<16000 {
            micChannel[i] = sin(Float(i) * 2.0 * .pi * 440.0 / 16000.0) * 0.4 // 440Hz Sine
        }
        try micFile.write(from: micBuffer)
        
        // Write 1 second of synthetic audio to sys
        let sysFile = try AVAudioFile(forWriting: sysURL, settings: pcmFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let sysBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 16000) else {
            XCTFail("Failed to create sys PCM buffer")
            return
        }
        sysBuffer.frameLength = 16000
        let sysChannel = sysBuffer.floatChannelData![0]
        for i in 0..<16000 {
            sysChannel[i] = sin(Float(i) * 2.0 * .pi * 880.0 / 16000.0) * 0.3 // 880Hz Sine
        }
        try sysFile.write(from: sysBuffer)
        
        // Run Mixdown
        let mixedURL = try AudioRecorder.mixdownBuffers(micURL: micURL, sysURL: sysURL, destinationURL: outM4AURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: mixedURL.path))
        
        // Verify output file size is compact (< 50KB for 1s AAC)
        let attr = try FileManager.default.attributesOfItem(atPath: mixedURL.path)
        let size = (attr[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size, 1000, "Output AAC file should contain valid audio data")
        XCTAssertLessThan(size, 100 * 1024, "1 second of AAC mono should be well under 100KB")
        
        // Verify file can be read back by AVAudioFile
        let readFile = try AVAudioFile(forReading: mixedURL)
        XCTAssertEqual(readFile.fileFormat.sampleRate, 16000.0)
        XCTAssertEqual(readFile.fileFormat.channelCount, 1)
        XCTAssertGreaterThan(readFile.length, 14000)
    }
    
    // 4. Test Config Save and Load
    func testConfigSaveAndLoad() {
        let testKey = "gsk_live_test_key_sample_\(UUID().uuidString.prefix(6))"
        Config.shared.saveGroqApiKey(testKey)
        XCTAssertEqual(Config.shared.groqApiKey, testKey)
    }
}
