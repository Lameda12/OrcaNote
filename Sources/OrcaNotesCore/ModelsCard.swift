import SwiftUI
import AppKit

/// Settings for the free, open models: speech (Whisper) and the AI that writes summaries (Ollama).
@MainActor
public final class ModelsViewModel: ObservableObject {
    public static let shared = ModelsViewModel()

    @Published public var ollamaRunning = false
    @Published public var installed: [String] = []
    @Published public var pullProgress: Double?      // nil = not downloading, -1 = indeterminate
    @Published public var pullStatus = ""

    public init() {}

    public func refresh() {
        Task {
            ollamaRunning = await OllamaService.isRunning()
            installed = ollamaRunning ? await OllamaService.installedModels() : []
        }
    }

    public func download(_ model: String) {
        pullProgress = -1
        pullStatus = "Starting download…"
        Task {
            do {
                try await OllamaService.pull(model) { p, status in
                    Task { @MainActor in
                        self.pullProgress = p
                        self.pullStatus = status
                    }
                }
                pullProgress = nil
                pullStatus = ""
            } catch {
                pullProgress = nil
                pullStatus = "Download failed: \(error.localizedDescription)"
            }
            refresh()
        }
    }

    public func openOllama() {
        let app = URL(fileURLWithPath: "/Applications/Ollama.app")
        if FileManager.default.fileExists(atPath: app.path) {
            NSWorkspace.shared.openApplication(at: app, configuration: .init()) { _, _ in }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.refresh() }
        } else {
            NSWorkspace.shared.open(URL(string: "https://ollama.com/download")!)
        }
    }
}

public struct ModelsCard: View {
    @ObservedObject private var vm = ModelsViewModel.shared
    @ObservedObject private var stt = LocalTranscriber.shared
    @ObservedObject private var state = AppState.shared
    @State private var speechModel = Preferences.speechModel
    @State private var provider = Preferences.aiProvider
    @State private var llm = Preferences.localLLM

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FREE AI MODELS").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)

            // Speech
            Picker("Speech model", selection: $speechModel) {
                ForEach(ModelCatalog.speechModels) { m in
                    Text("\(m.label) · \(m.sizeMB) MB").tag(m.id)
                }
            }
            .onChange(of: speechModel) { v in
                Preferences.speechModel = v
                if Preferences.useLocalSTT { LocalTranscriber.shared.switchModel() }
            }
            Text("OpenAI Whisper, MIT license. Runs on this Mac. Downloaded once from Hugging Face.")
                .font(.system(size: 10)).foregroundColor(.secondary)

            Divider().padding(.vertical, 2)

            // Summaries / polish
            Picker("Summaries & polish", selection: $provider) {
                ForEach(AIProvider.supported) { Text($0.label).tag($0) }
            }
            .onChange(of: provider) { v in Preferences.aiProvider = v; vm.refresh() }

            switch provider {
            case .local: localSection
            case .apple:
                Text(AppleIntelligence.unavailableReason ?? "Built into macOS 26. Free, private, no download.")
                    .font(.system(size: 10)).foregroundColor(AppleIntelligence.isAvailable ? .secondary : .orange)
            case .groq:
                Text(state.hasApiKey ? "Uses Groq Llama 3.3 70B. Transcripts are sent to Groq." : "Add a Groq key below to use the cloud.")
                    .font(.system(size: 10)).foregroundColor(state.hasApiKey ? .secondary : .orange)
            case .off:
                Text("Notes will contain the transcript without a summary.")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
        }
        .font(.system(size: 12))
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        .onAppear { vm.refresh() }
    }

    @ViewBuilder private var localSection: some View {
        if !vm.ollamaRunning {
            Text("Needs Ollama, a free app that runs open models (Llama, Qwen, Gemma) on your Mac.")
                .font(.system(size: 10)).foregroundColor(.orange)
            HStack {
                Button("Open / Get Ollama") { vm.openOllama() }.controlSize(.small)
                Button("Check again") { vm.refresh() }.controlSize(.small)
            }
        } else {
            Picker("Model", selection: $llm) {
                ForEach(ModelCatalog.llmChoices(installed: vm.installed), id: \.self) { id in
                    let opt = ModelCatalog.llms.first { $0.id == id }
                    let mark = ModelCatalog.isInstalled(id, in: vm.installed) ? "✓ " : ""
                    Text(mark + (opt.map { "\($0.label) · \(String(format: "%.1f", $0.sizeGB)) GB" } ?? id)).tag(id)
                }
            }
            .onChange(of: llm) { Preferences.localLLM = $0 }

            if let p = vm.pullProgress {
                if p < 0 { ProgressView { Text(vm.pullStatus).font(.system(size: 10)) } }
                else { ProgressView(value: p) { Text("Downloading \(Int(p * 100))%").font(.system(size: 10)) } }
            } else if !ModelCatalog.isInstalled(llm, in: vm.installed) {
                Button("Download \(llm)") { vm.download(llm) }.controlSize(.small)
            } else {
                Text("Ready. Runs fully on this Mac.").font(.system(size: 10)).foregroundColor(.secondary)
            }
            if !vm.pullStatus.isEmpty, vm.pullProgress == nil {
                Text(vm.pullStatus).font(.system(size: 10)).foregroundColor(.orange)
            }
        }
    }
}
