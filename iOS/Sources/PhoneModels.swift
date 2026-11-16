import Foundation
import HuggingFace
import Tokenizers
import MLXLMCommon
import MLXLLM
import OrcaShared

// MARK: - Adapters (Hugging Face downloader + tokenizer -> MLX protocols)

/// Downloads model snapshots from Hugging Face into a cache we control.
struct HubDownloader: MLXLMCommon.Downloader {
    let client: HubClient

    func download(id: String, revision: String?, matching patterns: [String], useLatest: Bool,
                  progressHandler: @Sendable @escaping (Progress) -> Void) async throws -> URL {
        guard let repo = Repo.ID(rawValue: id) else {
            throw LLMError.unavailable("Invalid model id \(id)")
        }
        return try await client.downloadSnapshot(of: repo, revision: revision ?? "main", matching: patterns,
                                                 progressHandler: { @MainActor p in progressHandler(p) })
    }
}

struct TokenizerBridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] { upstream.encode(text: text, addSpecialTokens: addSpecialTokens) }
    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String { upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens) }
    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }
    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(upstream: try await AutoTokenizer.from(modelFolder: directory))
    }
}

// MARK: - Model store (download / delete / status)

/// Open phone-sized models: downloaded on demand into Application Support (hidden, not backed up).
@MainActor
final class PhoneModels: ObservableObject {
    static let shared = PhoneModels()

    @Published private(set) var installed: Set<String> = []
    @Published private(set) var downloading: String?
    @Published private(set) var progress: Double = 0
    @Published var error: String?

    let cacheDirectory: URL = {
        var dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LLMs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? dir.setResourceValues(v)
        return dir
    }()

    var downloader: HubDownloader { HubDownloader(client: HubClient(cache: HubCache(cacheDirectory: cacheDirectory))) }

    private init() {
        installed = Set(UserDefaults.standard.stringArray(forKey: "phoneLLM.installed") ?? [])
            .filter { FileManager.default.fileExists(atPath: repoDirectory($0).path) }
    }

    func repoDirectory(_ id: String) -> URL {
        cacheDirectory.appendingPathComponent("models--" + id.replacingOccurrences(of: "/", with: "--"))
    }

    func isInstalled(_ id: String) -> Bool { installed.contains(id) }

    func download(_ id: String) {
        guard downloading == nil else { return }
        downloading = id; progress = 0; error = nil
        Task {
            do {
                _ = try await downloader.download(id: id, revision: nil,
                                                  matching: ["*.safetensors", "*.json", "*.jinja", "*.txt", "*.model"],
                                                  useLatest: false) { p in
                    Task { @MainActor in PhoneModels.shared.progress = p.fractionCompleted }
                }
                installed.insert(id)
                persist()
            } catch {
                self.error = "Download failed: \(error.localizedDescription)"
            }
            downloading = nil
        }
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: repoDirectory(id))
        installed.remove(id)
        persist()
    }

    private func persist() { UserDefaults.standard.set(Array(installed), forKey: "phoneLLM.installed") }
}

// MARK: - Engine

/// Runs the selected open model with MLX. The model is loaded per request and released afterwards,
/// so it never sits in memory next to the speech model.
final class MLXPhoneEngine: OnDeviceLLMEngine {
    func respond(system: String, user: String, maxTokens: Int) async throws -> String {
        #if targetEnvironment(simulator)
        throw LLMError.unavailable("Open models need a real iPhone or iPad (MLX does not run in the Simulator).")
        #else
        let id = Preferences.phoneLLM
        guard let option = ModelCatalog.phoneLLM(id) else { throw LLMError.unavailable("Unknown model \(id).") }
        guard await PhoneModels.shared.isInstalled(id) else {
            throw LLMError.unavailable("\(option.label) is not downloaded yet. Download it in Settings.")
        }
        let configuration = ModelConfiguration(id: id, extraEOSTokens: Set(option.eosTokens))
        let container = try await LLMModelFactory.shared.loadContainer(
            from: await PhoneModels.shared.downloader,
            using: TransformersTokenizerLoader(),
            configuration: configuration)
        let instructions = option.disableThinking ? system + "\n/no_think" : system
        let session = ChatSession(container, instructions: instructions,
                                  generateParameters: GenerateParameters(maxTokens: min(maxTokens, 1024), temperature: 0.3))
        return try await session.respond(to: user)
        #endif
    }
}
