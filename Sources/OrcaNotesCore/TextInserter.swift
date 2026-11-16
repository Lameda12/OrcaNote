import AppKit
import ApplicationServices

/// Types text into whatever app has focus by pasting (needs Accessibility permission).
public enum TextInserter {
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    public static func requestAccessibility() -> Bool {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Pastes `text` at the cursor, then restores the previous clipboard text.
    /// Returns false (text left on the clipboard) if Accessibility isn't granted.
    @MainActor
    public static func insert(_ text: String) async -> Bool {
        let pb = NSPasteboard.general
        let previous = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        guard hasAccessibility else { return false }

        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        try? await Task.sleep(nanoseconds: 450_000_000)
        if let previous, pb.string(forType: .string) == text {
            pb.clearContents()
            pb.setString(previous, forType: .string)
        }
        return true
    }
}
