# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- iPhone and iPad app: meeting recording with live captions, on-device transcription, dictation with styles, notes in the Files app.
- Apple Intelligence (on-device) as a summary provider on iOS 26 and macOS 26.
- Adaptive speech detection for live captions (works with quiet and noisy microphones).
- Open models on iPhone and iPad (Qwen3 1.7B, Gemma 3 1B, Llama 3.2 1B, Qwen3.5 2B) for summaries through MLX, with in-app download and delete.

### Changed
- Shared logic moved into a platform-neutral `OrcaShared` module.
- WhisperKit upgraded from 0.18 to 1.1.1; the universal Mac build now compiles each architecture separately.
- Whisper non-speech tags such as `[silence]` and `(laughs)` are removed from transcripts.
- Single-source transcripts are now "Timestamped Transcript" without speaker labels.
- Clearer summary prompt so small models don't copy placeholder text.

## [1.0.0] - 2026-11-16

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
