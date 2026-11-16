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
    case local, apple, openModel, groq, off
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .local: return "On-device (Ollama)"
        case .apple: return "Apple Intelligence (on-device)"
        case .openModel: return "Open model on device (Gemma, Qwen, Llama)"
        case .groq: return "Groq (cloud)"
        case .off: return "Off"
        }
    }

    /// Providers that can work on this platform. Ollama does not run on iOS.
    public static var supported: [AIProvider] {
        #if os(iOS)
        return [.apple, .openModel, .groq, .off]
        #else
        return [.local, .apple, .groq, .off]
        #endif
    }

    public static var platformDefault: AIProvider {
        #if os(iOS)
        return .apple
        #else
        return .local
        #endif
    }
}

/// Small open LLMs that fit on a phone (4-bit MLX builds from mlx-community on Hugging Face).
public struct PhoneLLMOption: Identifiable, Equatable {
    public let id: String          // Hugging Face repo
    public let label: String
    public let sizeGB: Double
    public let license: String
    /// Qwen3-family models "think" before answering unless told not to.
    public let disableThinking: Bool
    /// Extra end-of-turn tokens the model emits.
    public let eosTokens: [String]
}

public enum ModelCatalog {
    public static let defaultSpeechModel = "openai_whisper-base.en"
    public static let defaultLLM = "llama3.2:3b"
    /// Qwen3 1.7B gave the most accurate meeting summaries in testing.
    public static let defaultPhoneLLM = "mlx-community/Qwen3-1.7B-4bit"

    public static let phoneLLMs: [PhoneLLMOption] = [
        .init(id: "mlx-community/Qwen3-1.7B-4bit", label: "Qwen3 1.7B (Alibaba, recommended)", sizeGB: 0.98,
              license: "Apache 2.0", disableThinking: true, eosTokens: ["<|im_end|>"]),
        .init(id: "mlx-community/gemma-3-1b-it-qat-4bit", label: "Gemma 3 1B (Google)", sizeGB: 0.77,
              license: "Gemma Terms of Use", disableThinking: false, eosTokens: ["<end_of_turn>"]),
        .init(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", label: "Llama 3.2 1B (Meta)", sizeGB: 0.71,
              license: "Llama 3.2 Community License", disableThinking: false, eosTokens: ["<|eot_id|>"]),
        .init(id: "mlx-community/Qwen3.5-2B-4bit", label: "Qwen3.5 2B (Alibaba, best, newer phones)", sizeGB: 1.75,
              license: "Apache 2.0", disableThinking: true, eosTokens: ["<|im_end|>"])
    ]

    public static func phoneLLM(_ id: String) -> PhoneLLMOption? { phoneLLMs.first { $0.id == id } }

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
