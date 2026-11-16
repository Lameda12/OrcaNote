import Foundation

public class Config {
    public static var shared = Config()
    
    public private(set) var groqApiKey: String?
    public let notesDirectory: URL
    
    public init() {
        let envDict = Config.loadEnv()
        
        let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? envDict["GROQ_API_KEY"]
        self.groqApiKey = (key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? key?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        
        let customDir = ProcessInfo.processInfo.environment["NOTES_DIRECTORY"] ?? envDict["NOTES_DIRECTORY"]
        if let customDir = customDir, !customDir.isEmpty {
            let expanded = NSString(string: customDir).expandingTildeInPath
            self.notesDirectory = URL(fileURLWithPath: expanded)
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.notesDirectory = home.appendingPathComponent("MeetingNotes")
        }
        
        try? FileManager.default.createDirectory(at: self.notesDirectory, withIntermediateDirectories: true)
    }
    
    public func saveGroqApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        self.groqApiKey = trimmed
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let orcaEnvURL = home.appendingPathComponent(".orca.env")
        let content = "GROQ_API_KEY=\(trimmed)\n"
        try? content.write(to: orcaEnvURL, atomically: true, encoding: .utf8)
    }
    
    public static func parseEnvString(_ contents: String) -> [String: String] {
        var env: [String: String] = [:]
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let k = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                var v = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                    v = String(v.dropFirst().dropLast())
                }
                env[k] = v
            }
        }
        return env
    }
    
    private static func loadEnv() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchPaths: [URL] = [
            home.appendingPathComponent(".orca.env"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"),
            home.appendingPathComponent(".env"),
            home.appendingPathComponent("MeetingNotes").appendingPathComponent(".env"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(".env")
        ]
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                if let contents = try? String(contentsOf: path, encoding: .utf8) {
                    return parseEnvString(contents)
                }
            }
        }
        return [:]
    }
}
