# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Push-to-talk dictation (`⌃⌥Space`) that pastes into the focused app.
- On-device transcription with WhisperKit; Groq remains an optional fallback.
- Per-app writing styles (Verbatim, Clean, Casual, Professional) with offline cleanup rules.
- Live captions during meetings with You/Them speaker labels and echo filtering.
- `.txt` and `.json` transcript export next to Markdown notes.
- Meeting app detection (Zoom, Teams, FaceTime, Webex).
- Whale app icon, menu bar icon, and landing page favicons.

### Changed
- Builds are now universal (Apple Silicon and Intel).
- A Groq API key is no longer required to record meetings.
