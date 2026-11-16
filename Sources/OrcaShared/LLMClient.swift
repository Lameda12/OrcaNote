import Foundation

public enum LLMError: LocalizedError {
    case unavailable(String)
    case badResponse(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable(let m), .badResponse(let m): return m
        }
    }
}

/// Talks to the local Ollama server (http://localhost:11434). Ollama and its models are free and open.
public enum OllamaService {
    public static var baseURL = URL(string: "http://127.0.0.1:11434")!

    public static func isRunning() async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/version"))
        req.timeoutInterval = 1.5
        return ((try? await URLSession.shared.data(for: req))?.1 as? HTTPURLResponse)?.statusCode == 200
    }

    public static func installedModels() async -> [String] {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        req.timeoutInterval = 3
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    /// Downloads a model, reporting 0...1 progress.
    public static func pull(_ model: String, progress: @escaping @Sendable (Double, String) -> Void) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        req.httpMethod = "POST"
        req.timeoutInterval = 3600
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true])
        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LLMError.unavailable("Ollama refused the download.") }
        for try await line in bytes.lines {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            if let err = obj["error"] as? String { throw LLMError.unavailable(err) }
            let status = obj["status"] as? String ?? ""
            if let total = obj["total"] as? Double, total > 0, let done = obj["completed"] as? Double {
                progress(done / total, status)
            } else {
                progress(status == "success" ? 1 : -1, status)
            }
        }
    }

    public static func chat(model: String, system: String, user: String, timeout: TimeInterval, maxTokens: Int) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "options": ["temperature": 0.2, "num_ctx": 8192, "num_predict": maxTokens]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msg = json["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw LLMError.badResponse("Ollama error: \(String(data: data, encoding: .utf8) ?? "no response")")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A platform-supplied engine that runs an open model on this device (iOS registers an MLX engine).
public protocol OnDeviceLLMEngine: Sendable {
    func respond(system: String, user: String, maxTokens: Int) async throws -> String
}

public enum OnDeviceLLM {
    nonisolated(unsafe) public static var engine: (any OnDeviceLLMEngine)?

    /// Removes <think>…</think> reasoning blocks (Qwen3 family), including an unterminated one.
    public static func stripThinking(_ text: String) -> String {
        var t = text.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
        if let open = t.range(of: "<think>") { t = String(t[..<open.lowerBound]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One entry point for summaries and polish, whichever provider the user picked.
public enum LLMClient {
    public static func chat(system: String, user: String, timeout: TimeInterval = 120, maxTokens: Int = 2048) async throws -> String {
        switch Preferences.aiProvider {
        case .off:
            throw LLMError.unavailable("AI is turned off.")
        case .local:
            #if os(iOS)
            throw LLMError.unavailable("Ollama is not available on iPhone.")
            #endif
            guard await OllamaService.isRunning() else {
                throw LLMError.unavailable("Ollama is not running. Install it free from ollama.com, then open it.")
            }
            let model = Preferences.localLLM
            guard ModelCatalog.isInstalled(model, in: await OllamaService.installedModels()) else {
                throw LLMError.unavailable("Model \(model) is not downloaded yet. Download it in OrcaNotes settings.")
            }
            return try await OllamaService.chat(model: model, system: system, user: user, timeout: timeout, maxTokens: maxTokens)
        case .apple:
            return try await AppleIntelligence.respond(system: system, user: user)
        case .openModel:
            guard let engine = OnDeviceLLM.engine else {
                throw LLMError.unavailable("Open models are not available in this build.")
            }
            let raw = try await engine.respond(system: system, user: user, maxTokens: maxTokens)
            return OnDeviceLLM.stripThinking(raw)
        case .groq:
            guard let key = Secrets.groqKey else { throw LLMError.unavailable("Add a Groq API key first.") }
            return try await groqChat(system: system, user: user, key: key, timeout: timeout, maxTokens: maxTokens)
        }
    }

    static func groqChat(system: String, user: String, key: String, timeout: TimeInterval, maxTokens: Int) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "temperature": 0.2,
            "max_tokens": maxTokens
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msg = (json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw LLMError.badResponse("Groq error (\(code)): \(String(data: data, encoding: .utf8) ?? "")")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits long text on paragraph/sentence boundaries into chunks of at most `limit` characters.
    public static func chunk(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }
        var chunks: [String] = []
        var current = ""
        for piece in text.components(separatedBy: CharacterSet(charactersIn: "\n.")) where !piece.isEmpty {
            let p = piece + "."
            if current.count + p.count > limit, !current.isEmpty {
                chunks.append(current); current = ""
            }
            if p.count > limit {
                var rest = Substring(p)
                while !rest.isEmpty { chunks.append(String(rest.prefix(limit))); rest = rest.dropFirst(limit) }
            } else {
                current += (current.isEmpty ? "" : " ") + p.trimmingCharacters(in: .whitespaces)
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// Rejects LLM output that drifted away from a rewrite (chatter, empty, wildly longer).
    public static func acceptPolish(original: String, output: String) -> Bool {
        let o = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return false }
        if o.count > original.count * 2 + 40 { return false }
        let lower = o.lowercased()
        return !(lower.hasPrefix("here is") || lower.hasPrefix("here's") || lower.hasPrefix("sure"))
    }
}
