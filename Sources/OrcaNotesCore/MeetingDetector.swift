import AppKit

/// Detects well-known meeting apps that are running, so the UI can suggest recording.
public enum MeetingDetector {
    public static let knownApps: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.microsoft.teams": "Microsoft Teams",
        "com.apple.FaceTime": "FaceTime",
        "com.cisco.webexmeetingsapp": "Webex"
    ]

    public static func runningMeetingApp(from apps: [NSRunningApplication] = NSWorkspace.shared.runningApplications) -> String? {
        for app in apps where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier, let name = knownApps[id] { return name }
        }
        return nil
    }
}
