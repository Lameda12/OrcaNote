import Foundation
import WhisperKit

/// On-device speech-to-text (WhisperKit / CoreML). Model downloads on first use.
@MainActor
public final class LocalTranscriber: ObservableObject {
    public static let shared = LocalTranscriber()

    public enum Status: Equatable {
        case notLoaded
        case loading(String)
        case ready
        case failed(String)
    }

    @Published public private(set) var status: Status = .notLoaded
    @Published public private(set) var downloadProgress: Double = 0

    public static let modelName = "openai_whisper-base.en"
    private var kit: WhisperKit?
    private var loadTask: Task<Void, Never>?

    public init() {}

    public func prepare() {
        guard kit == nil, loadTask == nil else { return }
        status = .loading("Downloading speech model…")
        loadTask = Task { [weak self] in
            do {
                let folder = try await WhisperKit.download(variant: LocalTranscriber.modelName) { p in
                    Task { @MainActor in self?.downloadProgress = p.fractionCompleted }
                }
                self?.status = .loading("Loading speech model…")
                let config = WhisperKitConfig(modelFolder: folder.path, verbose: false, prewarm: true, load: true, download: false)
                self?.kit = try await WhisperKit(config)
                self?.status = .ready
            } catch {
                self?.status = .failed(error.localizedDescription)
            }
            self?.loadTask = nil
        }
    }

    public func transcribe(audioURL: URL) async throws -> String {
        if kit == nil { prepare() }
        await loadTask?.value
        guard let kit else {
            throw PipelineError.transcriptionFailed("Local model unavailable. Using cloud fallback if a Groq key is set.")
        }
        let results = try await kit.transcribe(audioPath: audioURL.path)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Transcribes raw 16 kHz mono samples (used by live captions). Returns "" if the model isn't ready.
    public func transcribe(samples: [Float]) async -> String {
        guard let kit else { prepare(); return "" }
        let results = try? await kit.transcribe(audioArray: samples)
        return (results ?? []).map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
