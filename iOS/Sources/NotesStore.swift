import Foundation
import OrcaShared

struct Note: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var title: String { url.deletingPathExtension().lastPathComponent }
    var date: Date
}

/// Notes live in the app's Documents folder, visible in the Files app under "OrcaNotes".
@MainActor
final class NotesStore: ObservableObject {
    static let shared = NotesStore()
    @Published private(set) var notes: [Note] = []

    let directory: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        notes = files.filter { $0.pathExtension == "md" }.map { url in
            Note(url: url, date: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }.sorted { $0.date > $1.date }
    }

    func newBaseName(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm-ss"
        return f.string(from: date)
    }

    /// Writes the Markdown note plus .txt and .json transcripts next to the audio.
    func save(base: String, audioURL: URL, duration: TimeInterval, summary: String, transcript: String, speakerTranscript: String?) throws -> URL {
        let date = Date()
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        let mins = Int(duration) / 60, secs = Int(duration) % 60
        var md = """
        # Meeting Notes — \(df.string(from: date))

        **Duration:** \(mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s")
        **Audio:** \(audioURL.lastPathComponent)

        \(summary)

        ---

        ## Full Transcript

        \(transcript)
        """
        if let speakerTranscript { md += "\n\n---\n\n## Timestamped Transcript\n\n\(speakerTranscript)\n" }
        let noteURL = directory.appendingPathComponent("\(base).md")
        try md.write(to: noteURL, atomically: true, encoding: .utf8)
        try? transcript.write(to: directory.appendingPathComponent("\(base).txt"), atomically: true, encoding: .utf8)
        let json: [String: Any] = ["date": ISO8601DateFormatter().string(from: date),
                                   "durationSeconds": Int(duration),
                                   "transcript": transcript]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("\(base).json"))
        }
        refresh()
        return noteURL
    }

    func delete(_ note: Note) {
        let base = note.url.deletingPathExtension()
        for ext in ["md", "txt", "json", "m4a"] {
            try? FileManager.default.removeItem(at: base.appendingPathExtension(ext))
        }
        refresh()
    }
}
