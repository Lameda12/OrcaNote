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

public enum AudioSource: String, Sendable { case mic, system }

/// Platform code supplies the Groq key (macOS: ~/.orca.env, iOS: Keychain).
public enum Secrets {
    nonisolated(unsafe) public static var groqKeyProvider: () -> String? = { nil }
    public static var groqKey: String? {
        guard let k = groqKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty else { return nil }
        return k
    }
}

/// Writes structured notes from a transcript with whichever AI provider the user picked.
public enum Summarizer {
    public static let prompt = """
    You are an executive meeting assistant. Read the meeting transcript and write structured notes in Markdown with exactly these three sections:

    ## Executive Summary
    Three to five bullets: context, key updates, blockers, decisions and the main takeaway.

    ## Decisions Made
    One bullet per explicit agreement or confirmed decision.

    ## Action Items
    One checklist line per task, written as "- [ ] **Name**: task (deadline)". Use the real person's name from the transcript, or "Team" if nobody is named. Leave out the deadline if none was mentioned.

    Use "-" for bullets. Only include facts from the transcript. No preamble, no closing remarks, no placeholder text.
    """

    /// Characters per part; smaller models have smaller context windows.
    public static func chunkLimit(for provider: AIProvider) -> Int {
        switch provider {
        case .apple: return 6_000
        case .local: return 12_000
        case .groq, .off: return 40_000
        }
    }

    /// Never throws: on failure the note still saves, with a short explanation instead of a summary.
    public static func summarize(transcript: String) async -> String {
        let provider = Preferences.aiProvider
        guard provider != .off else {
            return "## Summary\n\n_AI summaries are turned off. The full transcript is below._"
        }
        do {
            let parts = LLMClient.chunk(transcript, limit: chunkLimit(for: provider))
            var material = transcript
            if parts.count > 1 {
                var notes: [String] = []
                for (i, part) in parts.enumerated() {
                    notes.append(try await LLMClient.chat(
                        system: "Summarize this part of a meeting transcript as concise bullet notes. Keep names, numbers, decisions and action items. No preamble.",
                        user: "Part \(i + 1) of \(parts.count):\n\n\(part)", maxTokens: 700))
                }
                material = notes.joined(separator: "\n\n")
            }
            let label = parts.count > 1 ? "Notes from each part of the meeting" : "Meeting Transcript"
            return try await LLMClient.chat(system: prompt, user: "\(label):\n\n\(material)", timeout: 300)
        } catch {
            return "## Summary\n\n_No summary: \(error.localizedDescription) The full transcript is below._"
        }
    }
}
