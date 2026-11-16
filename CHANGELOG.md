# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Speech model picker: six free Whisper models (Tiny to Large v3 Turbo, English and multilingual), downloaded on demand.
- Free local AI summaries and dictation polish through Ollama, with in-app model downloads (Llama 3.2, Qwen 2.5, Gemma 3).
- Long meetings are summarized in parts to fit small local models.
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
- Summaries default to on-device AI; Groq is now an optional provider.
- "Polish with Groq" became "AI polish", using whichever provider is selected.
