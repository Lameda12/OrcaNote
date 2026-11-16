import Foundation

/// Public legal and support pages, shown in Settings on every platform.
public enum LegalLinks {
    public struct Item: Sendable {
        public let title: String
        public let url: URL
    }

    private static let repo = "https://github.com/Lameda12/OrcaNote"

    public static let privacy = URL(string: "\(repo)/blob/main/PRIVACY.md")!
    public static let terms = URL(string: "\(repo)/blob/main/TERMS.md")!
    public static let appleEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let support = URL(string: "\(repo)/issues")!

    public static let all: [Item] = [
        .init(title: "Privacy Policy", url: privacy),
        .init(title: "Terms of Use", url: terms),
        .init(title: "Apple Standard EULA", url: appleEULA),
        .init(title: "Support", url: support)
    ]
}
