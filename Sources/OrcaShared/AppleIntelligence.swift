import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's built-in on-device language model (iOS 26 / macOS 26, Apple Intelligence devices). Free, private, no download.
public enum AppleIntelligence {
    /// nil when available, otherwise a user-facing reason.
    public static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(.deviceNotEligible): return "This device does not support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings."
            case .unavailable(.modelNotReady): return "Apple Intelligence is still downloading. Try again later."
            case .unavailable: return "Apple Intelligence is unavailable."
            }
        }
        return "Requires iOS 26 or macOS 26."
        #else
        return "Apple Intelligence is not supported by this build."
        #endif
    }

    public static var isAvailable: Bool { unavailableReason == nil }

    public static func respond(system: String, user: String) async throws -> String {
        if let reason = unavailableReason { throw LLMError.unavailable(reason) }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw LLMError.unavailable("Apple Intelligence is unavailable.")
    }
}
