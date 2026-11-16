import Foundation

public enum PipelineError: LocalizedError, Equatable {
    case apiKeyMissing
    case transcriptionFailed(String)
    case summaryFailed(String)
    case writeFailed(String)
    case fileTooLarge(Int64)
    
    public var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "GROQ_API_KEY is missing. Please set GROQ_API_KEY in .env or ~/.orca.env (Get a key at console.groq.com)."
        case .transcriptionFailed(let msg):
            return "Groq Whisper transcription failed: \(msg)"
        case .summaryFailed(let msg):
            return "Groq LLM summary generation failed: \(msg)"
        case .writeFailed(let msg):
            return "Failed to save meeting notes to disk: \(msg)"
        case .fileTooLarge(let bytes):
            let mb = Double(bytes) / (1024 * 1024)
            return String(format: "Audio file is %.1f MB, exceeding Groq's 25 MB limit.", mb)
        }
    }
}

public final class MeetingPipeline {
    public static let shared = MeetingPipeline()
    
    private let groqWhisperURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    private let groqChatURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    
    public init() {}
    
    public func processMeeting(audioURL: URL, duration: TimeInterval, speakerTranscript: String? = nil) async throws -> URL {
        let apiKey = Config.shared.groqApiKey

        if !Preferences.useLocalSTT {
            guard apiKey != nil else { throw PipelineError.apiKeyMissing }
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = (attributes[.size] as? Int64) ?? 0
            if fileSize > (25 * 1024 * 1024) { throw PipelineError.fileTooLarge(fileSize) }
        }

        let transcript = try await Transcriber.transcribe(audioURL: audioURL)
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PipelineError.transcriptionFailed("Empty transcript. Check if audio had audible speech.")
        }

        let summaryMarkdown = await summarize(transcript: transcript)

        let noteURL = try saveMeetingNote(audioURL: audioURL, duration: duration, summaryMarkdown: summaryMarkdown, transcript: transcript, speakerTranscript: speakerTranscript)
        exportTranscript(baseURL: noteURL.deletingPathExtension(), transcript: speakerTranscript ?? transcript, duration: duration)
        return noteURL
    }

    /// Writes plain-text and JSON transcripts next to the Markdown note.
    public func exportTranscript(baseURL: URL, transcript: String, duration: TimeInterval) {
        try? transcript.write(to: baseURL.appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        let payload: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "durationSeconds": Int(duration),
            "transcript": transcript
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: baseURL.appendingPathExtension("json"))
        }
    }

    public func transcribeWithGroq(audioURL: URL, apiKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: groqWhisperURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        let audioData = try Data(contentsOf: audioURL)
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-large-v3-turbo\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("text\r\n".data(using: .utf8)!)
        
        let filename = audioURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PipelineError.transcriptionFailed("Invalid network response.")
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw PipelineError.transcriptionFailed("Groq API Error (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        if let rawText = String(data: data, encoding: .utf8) {
            return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        throw PipelineError.transcriptionFailed("Unable to decode response.")
    }
    
    static let summaryPrompt = """
    You are an executive meeting assistant. Analyze the meeting transcript and write structured notes.

    Strict output structure:

    ## Executive Summary
    - 3 to 5 bullets covering context, key updates, blockers, decisions and the main takeaway

    ## Decisions Made
    - Every explicit agreement or confirmed decision

    ## Action Items
    - [ ] **Owner or role**: Task (deadline or context if mentioned)

    No preamble or greetings. Output only the Markdown.
    """

    /// Summarizes with the provider the user picked. Long transcripts are summarized in parts first.
    /// Never throws: on failure the note still saves, with a short explanation instead of a summary.
    public func summarize(transcript: String) async -> String {
        guard Preferences.aiProvider != .off else {
            return "## Summary\n\n_AI summaries are turned off. The full transcript is below._"
        }
        do {
            // Local models have a smaller context window, so use smaller parts.
            let limit = Preferences.aiProvider == .local ? 12_000 : 40_000
            let parts = LLMClient.chunk(transcript, limit: limit)
            var material = transcript
            if parts.count > 1 {
                var notes: [String] = []
                for (i, part) in parts.enumerated() {
                    let n = try await LLMClient.chat(
                        system: "Summarize this part of a meeting transcript as concise bullet notes. Keep names, numbers, decisions and action items. No preamble.",
                        user: "Part \(i + 1) of \(parts.count):\n\n\(part)", maxTokens: 700)
                    notes.append(n)
                }
                material = notes.joined(separator: "\n\n")
            }
            let label = parts.count > 1 ? "Notes from each part of the meeting" : "Meeting Transcript"
            return try await LLMClient.chat(system: MeetingPipeline.summaryPrompt, user: "\(label):\n\n\(material)", timeout: 300)
        } catch {
            return "## Summary\n\n_No summary: \(error.localizedDescription) The full transcript is below._"
        }
    }

    public static func formatMarkdownDocument(dateStr: String, timeStr: String, durationStr: String, audioFileName: String, audioFilePath: String, summaryMarkdown: String, transcript: String, speakerTranscript: String? = nil) -> String {
        return """
        # Meeting Notes — \(dateStr) \(timeStr)
        
        **Date:** \(dateStr)  
        **Time:** \(timeStr)  
        **Duration:** \(durationStr)  
        **Audio File:** [\(audioFileName)](file://\(audioFilePath))
        
        \(summaryMarkdown)
        
        ---
        
        ## Full Transcript
        
        \(transcript)
        \(speakerTranscript.map { "\n---\n\n## Transcript by Speaker\n\n" + $0 } ?? "")
        """
    }
    
    public func saveMeetingNote(audioURL: URL, duration: TimeInterval, summaryMarkdown: String, transcript: String, speakerTranscript: String? = nil) throws -> URL {
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let noteURL = Config.shared.notesDirectory.appendingPathComponent("\(baseName).md")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let now = Date()
        let dateStr = dateFormatter.string(from: now)
        let timeStr = timeFormatter.string(from: now)
        
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let durationStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
        
        let markdownContent = MeetingPipeline.formatMarkdownDocument(
            dateStr: dateStr,
            timeStr: timeStr,
            durationStr: durationStr,
            audioFileName: audioURL.lastPathComponent,
            audioFilePath: audioURL.path,
            summaryMarkdown: summaryMarkdown,
            transcript: transcript,
            speakerTranscript: speakerTranscript
        )
        
        do {
            try markdownContent.write(to: noteURL, atomically: true, encoding: .utf8)
        } catch {
            throw PipelineError.writeFailed(error.localizedDescription)
        }
        
        return noteURL
    }
}
