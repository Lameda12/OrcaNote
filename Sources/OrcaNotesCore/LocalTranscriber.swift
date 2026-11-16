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

    @Published public private(set) var loadedModel: String?
    private var kit: WhisperKit?
    private var loadTask: Task<Void, Never>?

    public init() {}

    /// Switch to the model chosen in Preferences (downloads it if needed).
    public func switchModel() {
        guard loadedModel != Preferences.speechModel else { return }
        loadTask?.cancel()
        loadTask = nil
        kit = nil
        loadedModel = nil
        prepare()
    }

    public func prepare() {
        guard kit == nil, loadTask == nil else { return }
        let variant = Preferences.speechModel
        downloadProgress = 0
        status = .loading("Downloading speech model…")
        loadTask = Task { [weak self] in
            do {
                let folder = try await WhisperKit.download(variant: variant) { p in
                    Task { @MainActor in self?.downloadProgress = p.fractionCompleted }
                }
                self?.status = .loading("Loading speech model…")
                let config = WhisperKitConfig(modelFolder: folder.path, verbose: false, prewarm: true, load: true, download: false)
                let kit = try await WhisperKit(config)
                guard !Task.isCancelled else { return }
                self?.kit = kit
                self?.loadedModel = variant
                self?.status = .ready
            } catch {
                guard !Task.isCancelled else { return }
                self?.status = .failed(error.localizedDescription)
            }
            if !Task.isCancelled { self?.loadTask = nil }
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
