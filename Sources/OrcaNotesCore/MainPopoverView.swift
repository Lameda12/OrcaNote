import SwiftUI
import AppKit

public struct MainPopoverView: View {
    @ObservedObject var state = AppState.shared
    @State private var tempKey = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("OrcaNotes")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.isShowingSettings.toggle()
                    }
                }) {
                    Image(systemName: state.isShowingSettings ? "xmark.circle.fill" : "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Models & settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.4)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if state.isShowingSettings {
                        ModelsCard()
                            .transition(.move(edge: .top).combined(with: .opacity))
                        apiKeyCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    mainRecordingCard
                    if state.isRecording { captionsCard }
                    if let app = MeetingDetector.runningMeetingApp(), !state.isRecording {
                        Label("\(app) is open — start recording when your call begins.", systemImage: "video.fill")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    dictationCard
                    audioInputsCard
                    
                    if !state.screenPermission || !state.micPermission {
                        permissionsCard
                    }
                    
                    recentNotesCard
                }
                .padding(16)
            }
            
            Divider()
                .opacity(0.4)
            
            HStack {
                Button(action: {
                    state.openNotesFolder()
                }) {
                    Label("Open Notes Folder", systemImage: "folder.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 330)
        .frame(maxHeight: 600)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text("Groq API Key (optional, cloud)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Link("Get Free Key ↗", destination: URL(string: "https://console.groq.com/keys")!)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            SecureField("Paste gsk_... key here", text: $tempKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            
            HStack {
                Text("Saved locally to ~/.orca.env")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Save Key") {
                    state.saveApiKey(tempKey)
                    tempKey = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    private var mainRecordingCard: some View {
        VStack(spacing: 12) {
            Text(state.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(state.isRecording ? .red : (state.isProcessing ? .blue : .secondary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32)
            
            Button(action: {
                withAnimation(.spring()) {
                    state.toggleRecording()
                }
            }) {
                HStack(spacing: 12) {
                    if state.isRecording {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stop & Generate Notes")
                                .font(.system(size: 13, weight: .bold))
                            Text(state.formattedTimer)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .opacity(0.8)
                        }
                    } else if state.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 24, height: 24)
                        Text("Processing...")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Image(systemName: "record.circle")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Start Meeting Recording")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(state.isRecording ? Color.red : (state.isProcessing ? Color.gray : Color.blue))
                )
                .shadow(color: (state.isRecording ? Color.red : Color.blue).opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(state.isProcessing)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ObservedObject private var dictation = DictationController.shared
    @ObservedObject private var stt = LocalTranscriber.shared
    @State private var localSTT = Preferences.useLocalSTT
    @State private var dictationOn = Preferences.dictationEnabled
    @State private var aiPolish = Preferences.aiPolish
    @State private var style = Preferences.defaultStyle

    @ObservedObject private var captions = LiveCaptioner.shared

    private var captionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LIVE CAPTIONS").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            if !captions.isActive {
                Text("Turn on on-device transcription to see live captions.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } else if captions.lines.isEmpty {
                Text("Listening… captions appear after a few seconds of speech.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            } else {
                ForEach(captions.lines.suffix(4)) { l in
                    (Text(l.speaker + ": ").bold().foregroundColor(l.speaker == "You" ? .blue : .orange) + Text(l.text))
                        .font(.system(size: 11))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private var dictationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DICTATION")
                .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
            Toggle("Push-to-talk (hold ⌃⌥Space)", isOn: $dictationOn)
                .onChange(of: dictationOn) { Preferences.dictationEnabled = $0 }
            Toggle("On-device transcription", isOn: $localSTT)
                .onChange(of: localSTT) { v in
                    Preferences.useLocalSTT = v
                    if v { LocalTranscriber.shared.prepare() }
                }
            if localSTT {
                switch stt.status {
                case .loading(let m):
                    ProgressView(value: stt.downloadProgress) { Text(m).font(.system(size: 10)) }
                case .failed(let e):
                    Text("Model error: \(e)").font(.system(size: 10)).foregroundColor(.orange)
                case .ready:
                    Text("Speech model ready").font(.system(size: 10)).foregroundColor(.secondary)
                case .notLoaded:
                    Text("Model downloads on first use. Change it in ⚙︎ settings.").font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Picker("Default style", selection: $style) {
                ForEach(WritingStyle.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: style) { Preferences.defaultStyle = $0 }
            Text("Mail/Outlook → Professional, Messages/Slack → Casual, Xcode/Terminal → Verbatim.")
                .font(.system(size: 10)).foregroundColor(.secondary)
            Toggle("AI polish (uses the summary model, slower)", isOn: $aiPolish)
                .onChange(of: aiPolish) { Preferences.aiPolish = $0 }
            if !TextInserter.hasAccessibility {
                Button("Grant Accessibility (needed to type into apps)") { TextInserter.requestAccessibility() }
                    .font(.system(size: 11))
            }
            if case .failed(let m) = dictation.phase { Text(m).font(.system(size: 10)).foregroundColor(.orange) }
        }
        .font(.system(size: 12))
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private var audioInputsCard: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Microphone")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.08))
            .cornerRadius(6)
            
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 11))
                Text("System Audio")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)
        }
    }
    
    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
                Text("macOS Permissions Required")
                    .font(.system(size: 11, weight: .bold))
            }
            
            if !state.screenPermission {
                HStack {
                    Text("• Screen/System Audio")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Grant") {
                        state.requestScreenPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            
            if !state.micPermission {
                HStack {
                    Text("• Microphone")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Grant") {
                        state.requestMicPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(8)
    }
    
    private var recentNotesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Meeting Notes")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    state.refreshRecentNotes()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if state.recentNotes.isEmpty {
                Text("No meeting notes yet. Start a recording above to create your first note!")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(state.recentNotes) { note in
                        Button(action: {
                            state.openNote(note)
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                Text(note.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
}

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
