import SwiftUI
import OrcaShared

@main
struct OrcaApp: App {
    init() {
        Secrets.groqKeyProvider = { Keychain.read("groqApiKey") }
        if !UserDefaults.standard.bool(forKey: "ios.didSetDefaults") {
            // iOS has no Ollama; on-device speech is the only transcription path.
            Preferences.useLocalSTT = true
            UserDefaults.standard.set(true, forKey: "ios.didSetDefaults")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { LocalTranscriber.shared.prepare() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "waveform") }
            NotesListView()
                .tabItem { Label("Notes", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
