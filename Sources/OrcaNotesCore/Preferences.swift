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
    /// Off by default: dictated text stays on this Mac unless the user opts in.
    public static var cloudCleanup: Bool {
        get { d.bool(forKey: "cloudCleanup") }
        set { d.set(newValue, forKey: "cloudCleanup") }
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
