import Foundation

/// How dictated text should read once it lands in an app.
public enum WritingStyle: String, CaseIterable, Identifiable, Codable {
    case verbatim      // exactly what was said
    case clean         // fillers removed, punctuation fixed
    case casual        // clean, relaxed, no trailing period
    case professional  // clean, complete sentences, polished tone

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .verbatim: return "Verbatim"
        case .clean: return "Clean"
        case .casual: return "Casual"
        case .professional: return "Professional"
        }
    }

    /// Instruction sent to an LLM when cloud cleanup is available.
    public var llmInstruction: String {
        switch self {
        case .verbatim:
            return "Return the text unchanged."
        case .clean:
            return "Remove filler words, false starts and repeated words. Fix capitalization and punctuation. Keep the speaker's wording and meaning."
        case .casual:
            return "Remove filler words and false starts. Keep a relaxed, conversational tone, short sentences, and no trailing period on a single sentence."
        case .professional:
            return "Remove filler words and false starts. Rewrite into polished, complete sentences with a courteous, professional tone. Do not add facts."
        }
    }
}

/// Maps the frontmost app to a writing style. User overrides win over built-in defaults.
public struct StyleRules {
    public static let defaults: [String: WritingStyle] = [
        "com.apple.mail": .professional,
        "com.microsoft.Outlook": .professional,
        "com.apple.iWork.Pages": .professional,
        "com.microsoft.Word": .professional,
        "com.apple.MobileSMS": .casual,
        "com.tinyspeck.slackmacgap": .casual,
        "com.hnc.Discord": .casual,
        "net.whatsapp.WhatsApp": .casual,
        "ru.keepcoder.Telegram": .casual,
        "com.apple.dt.Xcode": .verbatim,
        "com.apple.Terminal": .verbatim,
        "com.googlecode.iterm2": .verbatim,
        "com.microsoft.VSCode": .verbatim
    ]

    public var overrides: [String: WritingStyle]
    public var fallback: WritingStyle

    public init(overrides: [String: WritingStyle] = [:], fallback: WritingStyle = .clean) {
        self.overrides = overrides
        self.fallback = fallback
    }

    public func style(forBundleID id: String?) -> WritingStyle {
        guard let id else { return fallback }
        return overrides[id] ?? StyleRules.defaults[id] ?? fallback
    }
}

/// Offline, rule-based cleanup. Pure functions so it is fully testable and works with no network.
public enum TextCleanup {
    private static let fillerPattern = #"(?i)(?:^|(?<=[\s,]))(?:um+|uh+|uhm+|erm+|er|ah+|hmm+|you know)(?=[\s,.!?]|$)[,]?\s*"#
    private static let skipRepeat: Set<String> = ["had", "that", "very", "bye", "no"]

    public static func clean(_ raw: String, style: WritingStyle) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, style != .verbatim else { return text }

        text = applySpokenCommands(text)
        text = text.replacingOccurrences(of: fillerPattern, with: "", options: .regularExpression)
        text = collapseRepeats(text)
        text = text.replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bi\b(?!['’]m\b)"#, with: "I", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bi['’]m\b"#, with: "I'm", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = capitalizeSentences(text)

        let endsWithPunct = text.last.map { ".!?…\n".contains($0) } ?? true
        let singleSentence = !text.dropLast().contains(where: { ".!?".contains($0) })
        switch style {
        case .casual:
            if singleSentence, text.last == "." { text.removeLast() }
        case .clean, .professional:
            if !endsWithPunct { text += "." }
        case .verbatim:
            break
        }
        return text
    }

    static func applySpokenCommands(_ text: String) -> String {
        var t = text
        let map: [(String, String)] = [
            (#"(?i)[,.]?\s*\bnew paragraph\b[,.]?\s*"#, "\n\n"),
            (#"(?i)[,.]?\s*\bnew line\b[,.]?\s*"#, "\n"),
            (#"(?i)\s*\bquestion mark\b"#, "?"),
            (#"(?i)\s*\bexclamation (?:mark|point)\b"#, "!")
        ]
        for (pattern, repl) in map {
            t = t.replacingOccurrences(of: pattern, with: repl, options: .regularExpression)
        }
        return t
    }

    static func collapseRepeats(_ text: String) -> String {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var out: [String] = []
        for w in words {
            let norm = w.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let last = out.last,
               last.lowercased().trimmingCharacters(in: .punctuationCharacters) == norm,
               !norm.isEmpty, !skipRepeat.contains(norm), norm.count > 1 || norm == "a" || norm == "i" {
                continue
            }
            out.append(w)
        }
        return out.joined(separator: " ")
    }

    static func capitalizeSentences(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        for ch in text {
            if capitalizeNext, ch.isLetter {
                result.append(contentsOf: String(ch).uppercased())
                capitalizeNext = false
            } else {
                result.append(ch)
                if ".!?\n".contains(ch) { capitalizeNext = true }
                else if !ch.isWhitespace && !ch.isPunctuation { capitalizeNext = false }
            }
        }
        return result
    }
}
