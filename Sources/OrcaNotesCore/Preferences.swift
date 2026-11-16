import Foundation

/// User preferences, UserDefaults-backed.
public enum Preferences {
    private static let d = UserDefaults.standard

    public static var useLocalSTT: Bool {
        get { d.object(forKey: "useLocalSTT") as? Bool ?? true }
        set { d.set(newValue, forKey: "useLocalSTT") }
    }
    public static var dictationEnabled: Bool {
        get { d.object(forKey: "dictationEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "dictationEnabled") }
    }
    /// AI rewrite of dictated text. Off by default (adds latency).
    public static var aiPolish: Bool {
        get { d.bool(forKey: "aiPolish") }
        set { d.set(newValue, forKey: "aiPolish") }
    }
    /// Which AI writes meeting summaries and polish. Defaults to on-device.
    public static var aiProvider: AIProvider {
        get { AIProvider(rawValue: d.string(forKey: "aiProvider") ?? "") ?? .local }
        set { d.set(newValue.rawValue, forKey: "aiProvider") }
    }
    public static var localLLM: String {
        get { d.string(forKey: "localLLM") ?? ModelCatalog.defaultLLM }
        set { d.set(newValue, forKey: "localLLM") }
    }
    public static var speechModel: String {
        get { d.string(forKey: "speechModel") ?? ModelCatalog.defaultSpeechModel }
        set { d.set(newValue, forKey: "speechModel") }
    }
    public static var defaultStyle: WritingStyle {
        get { WritingStyle(rawValue: d.string(forKey: "defaultStyle") ?? "") ?? .clean }
        set { d.set(newValue.rawValue, forKey: "defaultStyle") }
    }
    public static var styleOverrides: [String: WritingStyle] {
        get {
            let raw = d.dictionary(forKey: "styleOverrides") as? [String: String] ?? [:]
            return raw.compactMapValues { WritingStyle(rawValue: $0) }
        }
        set { d.set(newValue.mapValues(\.rawValue), forKey: "styleOverrides") }
    }
    public static var styleRules: StyleRules {
        StyleRules(overrides: styleOverrides, fallback: defaultStyle)
    }
}
