import Foundation

/// Free, open speech models (OpenAI Whisper, MIT license) converted to Core ML by Argmax.
public struct SpeechModelOption: Identifiable, Equatable {
    public let id: String          // WhisperKit variant name
    public let label: String
    public let sizeMB: Int
    public let multilingual: Bool
}

/// Free, open LLMs served locally by Ollama.
public struct LLMOption: Identifiable, Equatable {
    public let id: String          // Ollama model tag
    public let label: String
    public let sizeGB: Double
}

public enum AIProvider: String, CaseIterable, Identifiable {
    case local, groq, off
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .local: return "On-device (Ollama)"
        case .groq: return "Groq (cloud)"
        case .off: return "Off"
        }
    }
}

public enum ModelCatalog {
    public static let defaultSpeechModel = "openai_whisper-base.en"
    public static let defaultLLM = "llama3.2:3b"

    public static let speechModels: [SpeechModelOption] = [
        .init(id: "openai_whisper-tiny.en", label: "Tiny (English, fastest)", sizeMB: 75, multilingual: false),
        .init(id: "openai_whisper-base.en", label: "Base (English)", sizeMB: 145, multilingual: false),
        .init(id: "openai_whisper-small.en", label: "Small (English, more accurate)", sizeMB: 480, multilingual: false),
        .init(id: "openai_whisper-base", label: "Base (99 languages)", sizeMB: 145, multilingual: true),
        .init(id: "openai_whisper-small", label: "Small (99 languages)", sizeMB: 480, multilingual: true),
        .init(id: "openai_whisper-large-v3-v20240930_turbo_632MB", label: "Large v3 Turbo (99 languages, best)", sizeMB: 632, multilingual: true)
    ]

    public static let llms: [LLMOption] = [
        .init(id: "llama3.2:3b", label: "Llama 3.2 3B (balanced)", sizeGB: 2.0),
        .init(id: "qwen2.5:3b", label: "Qwen 2.5 3B (multilingual)", sizeGB: 1.9),
        .init(id: "gemma3:4b", label: "Gemma 3 4B", sizeGB: 3.3),
        .init(id: "qwen2.5:7b", label: "Qwen 2.5 7B (best, 16 GB RAM+)", sizeGB: 4.7)
    ]

    public static func speechModel(_ id: String) -> SpeechModelOption? { speechModels.first { $0.id == id } }

    /// Catalog entries plus anything else already installed in Ollama.
    public static func llmChoices(installed: [String]) -> [String] {
        var out = llms.map(\.id)
        for m in installed where !out.contains(m) && !m.contains("embed") { out.append(m) }
        return out
    }

    /// Ollama tags may omit ":latest"; compare loosely.
    public static func isInstalled(_ model: String, in installed: [String]) -> Bool {
        installed.contains { $0 == model || $0 == model + ":latest" || $0.hasPrefix(model + ":") && !model.contains(":") }
    }
}
