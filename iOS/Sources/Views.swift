import SwiftUI
import OrcaShared

struct RecordView: View {
    @StateObject private var model = RecordModel()
    @ObservedObject private var captions = LiveCaptioner.shared
    @ObservedObject private var stt = LocalTranscriber.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Mode", selection: $model.mode) {
                        ForEach(RecordMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.isRecording || model.busy != nil)

                    if model.mode == .dictate {
                        Picker("Style", selection: $model.style) {
                            ForEach(WritingStyle.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    modelStatus

                    Button(action: model.toggle) {
                        ZStack {
                            Circle()
                                .fill(model.isRecording ? Color.red : Color.accentColor)
                                .frame(width: 140, height: 140)
                                .shadow(color: (model.isRecording ? Color.red : Color.accentColor).opacity(0.4), radius: 16)
                            Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(model.busy != nil)
                    .accessibilityLabel(model.isRecording ? "Stop recording" : "Start recording")

                    Text(model.isRecording ? model.timerText : (model.busy ?? "Tap to record"))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if model.busy != nil { ProgressView() }

                    if let e = model.error {
                        Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    if model.mode == .meeting && (model.isRecording || !captions.lines.isEmpty) {
                        captionsBox
                    }
                    if model.mode == .dictate && !model.dictation.isEmpty {
                        dictationBox
                    }
                }
                .padding()
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("OrcaNotes")
            .navigationDestination(item: $model.savedNote) { NoteDetailView(note: $0) }
        }
    }

    @ViewBuilder private var modelStatus: some View {
        switch stt.status {
        case .loading(let m):
            VStack(alignment: .leading) {
                ProgressView(value: stt.downloadProgress)
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
        case .failed(let e):
            Text("Speech model error: \(e)").font(.caption).foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private var captionsBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Live captions", systemImage: "captions.bubble").font(.headline)
            if captions.lines.isEmpty {
                Text("Captions appear after a few seconds of speech.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(captions.lines.suffix(8)) { line in
                Text(line.text).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var dictationBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Copied to clipboard", systemImage: "doc.on.clipboard").font(.headline)
            TextEditor(text: $model.dictation)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
            HStack {
                Button("Copy") { UIPasteboard.general.string = model.dictation }
                    .buttonStyle(.bordered)
                ShareLink(item: model.dictation) { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct NotesListView: View {
    @ObservedObject private var store = NotesStore.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.notes) { note in
                    NavigationLink(value: note) {
                        VStack(alignment: .leading) {
                            Text(note.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text(note.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in idx.map { store.notes[$0] }.forEach(store.delete) }
            }
            .overlay {
                if store.notes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "doc.text",
                                           description: Text("Record a meeting to create your first note."))
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.self) { NoteDetailView(note: $0) }
            .onAppear { store.refresh() }
            .refreshable { store.refresh() }
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @State private var text = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    MarkdownLine(line: line)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(note.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: note.url) { Image(systemName: "square.and.arrow.up") }
        }
        .onAppear { text = (try? String(contentsOf: note.url, encoding: .utf8)) ?? "" }
    }

}

/// Renders one line of the note's Markdown: headings, bullets, checkboxes, rules, inline bold.
struct MarkdownLine: View {
    let line: String

    var body: some View {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty {
            Spacer().frame(height: 4)
        } else if t == "---" {
            Divider().padding(.vertical, 6)
        } else if t.hasPrefix("# ") {
            Text(inline(String(t.dropFirst(2)))).font(.title2.bold())
        } else if t.hasPrefix("## ") {
            Text(inline(String(t.dropFirst(3)))).font(.headline).padding(.top, 8)
        } else if t.hasPrefix("- [ ] ") || t.hasPrefix("* [ ] ") {
            row("square", String(t.dropFirst(6)))
        } else if t.hasPrefix("- [x] ") || t.hasPrefix("* [x] ") {
            row("checkmark.square", String(t.dropFirst(6)))
        } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
            row("circle.fill", String(t.dropFirst(2)), small: true)
        } else {
            Text(inline(t))
        }
    }

    private func row(_ symbol: String, _ body: String, small: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(small ? .system(size: 5) : .body).foregroundStyle(.secondary)
            Text(inline(body.trimmingCharacters(in: .whitespaces)))
        }
        .padding(.leading, line.hasPrefix("  ") ? 16 : 0)
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }
}

struct SettingsView: View {
    @ObservedObject private var stt = LocalTranscriber.shared
    @State private var speechModel = Preferences.speechModel
    @State private var provider = Preferences.aiProvider
    @State private var style = Preferences.defaultStyle
    @State private var aiPolish = Preferences.aiPolish
    @State private var groqKey = Keychain.read("groqApiKey") ?? ""
    @State private var keyStatus = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Model", selection: $speechModel) {
                        ForEach(ModelCatalog.speechModels) { Text("\($0.label) · \($0.sizeMB) MB").tag($0.id) }
                    }
                    .onChange(of: speechModel) { _, v in
                        Preferences.speechModel = v
                        LocalTranscriber.shared.switchModel()
                    }
                    switch stt.status {
                    case .ready: Label("Ready, runs on this device", systemImage: "checkmark.circle").foregroundStyle(.green)
                    case .loading(let m): ProgressView(value: stt.downloadProgress) { Text(m) }
                    case .failed(let e): Text(e).foregroundStyle(.orange)
                    case .notLoaded: Text("Downloads on first use").foregroundStyle(.secondary)
                    }
                } header: { Text("Speech to text") } footer: {
                    Text("Free OpenAI Whisper models (MIT license). Downloaded once, then works offline. Large models need a recent iPhone.")
                }

                Section {
                    Picker("Provider", selection: $provider) {
                        ForEach(AIProvider.supported) { Text($0.label).tag($0) }
                    }
                    .onChange(of: provider) { _, v in Preferences.aiProvider = v }
                    if provider == .apple {
                        Text(AppleIntelligence.unavailableReason ?? "Free, private, built into iOS. No download.")
                            .font(.footnote).foregroundStyle(AppleIntelligence.isAvailable ? Color.secondary : Color.orange)
                    }
                    if provider == .groq {
                        SecureField("Groq API key (gsk_…)", text: $groqKey)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .onSubmit { Keychain.write("groqApiKey", groqKey) }
                        Button("Save key") {
                            let status = Keychain.write("groqApiKey", groqKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            keyStatus = status == errSecSuccess ? "Saved to Keychain" : "Could not save the key (error \(status))"
                        }
                        if !keyStatus.isEmpty { Text(keyStatus).font(.footnote).foregroundStyle(.secondary) }
                        Link("Get a free key", destination: URL(string: "https://console.groq.com/keys")!)
                    }
                    Toggle("AI polish for dictation", isOn: $aiPolish)
                        .onChange(of: aiPolish) { _, v in Preferences.aiPolish = v }
                } header: { Text("Summaries") } footer: {
                    Text(provider == .groq ? "Transcripts are sent to Groq. The key is stored in the Keychain." : "Everything stays on this device.")
                }

                Section("Dictation") {
                    Picker("Default style", selection: $style) {
                        ForEach(WritingStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: style) { _, v in Preferences.defaultStyle = v }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Link("Source code", destination: URL(string: "https://github.com/Lameda12/OrcaNote")!)
                    Text("Notes are saved in Files → On My iPhone → OrcaNotes.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
