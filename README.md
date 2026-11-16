<p align="center">
  <img src="assets/logo.png" alt="OrcaNotes logo" width="140" height="140">
</p>

<h1 align="center">OrcaNotes</h1>

<p align="center">
  <b>Private dictation and meeting notes for macOS.</b><br>
  Speak into any app, record calls with live captions, and keep every word on your Mac.
</p>

<p align="center">
  <a href="https://github.com/Lameda12/OrcaNote/actions/workflows/ci.yml"><img src="https://github.com/Lameda12/OrcaNote/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-green.svg" alt="Apple Silicon and Intel">
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome"></a>
</p>

---

## Features

| | |
|---|---|
| **Push-to-talk dictation** | Hold `⌃⌥Space`, speak, release. Text is pasted into the app you were using. A quick tap latches recording on until the next press. |
| **On-device transcription** | Speech-to-text runs locally with [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Core ML). Works offline after a one-time ~145 MB model download. |
| **Per-app writing styles** | Verbatim, Clean, Casual or Professional, chosen by the frontmost app. Mail gets Professional, Messages and Slack get Casual, Xcode and Terminal stay Verbatim. |
| **Meeting recording** | Captures your microphone and system audio (Zoom, Meet, Teams, browser tabs) with no virtual audio cable. |
| **Live captions** | See the conversation as it happens, labelled **You** (mic) and **Them** (system audio). |
| **Structured notes** | Optional AI summary with decisions and action items, saved as Markdown with `.txt` and `.json` transcripts. |
| **Privacy first** | No account, no telemetry, no cloud storage. Cloud features (Groq) are opt-in and off by default for dictation. |
| **Universal app** | One build for Apple Silicon and Intel Macs. |

## Install

### Download

Grab `OrcaNotes.dmg` from the [Releases](https://github.com/Lameda12/OrcaNote/releases) page, drag **OrcaNotes** to **Applications**, then run once:

```bash
xattr -cr /Applications/OrcaNotes.app && open /Applications/OrcaNotes.app
```

Builds are ad-hoc signed, not notarized, so Gatekeeper flags downloaded copies until you do this (or right-click the app, then **Open**).

### Build from source

Requires macOS 14+ and Xcode 15+ (Swift 5.9).

```bash
git clone https://github.com/Lameda12/OrcaNote.git
cd OrcaNote
make app      # builds build/OrcaNotes.app (universal)
make dmg      # builds build/OrcaNotes.dmg
make test     # runs the test suite
```

## Permissions

| Permission | Why |
|---|---|
| **Microphone** | Dictation and meeting recording. |
| **Accessibility** | Paste dictated text into other apps. Without it, text is left on your clipboard. |
| **Screen & System Audio Recording** | Capture the other side of a call through ScreenCaptureKit. |

Ad-hoc signed builds can lose the Accessibility grant after each rebuild. Re-grant it in **System Settings → Privacy & Security**.

## Optional: Groq

Local transcription needs no key. Add a free [Groq API key](https://console.groq.com/keys) to get AI meeting summaries, cloud transcription, or optional text polish. Paste it in the app, or copy `.env.example` to `.env`.

Dictated text is only sent to Groq if you switch on **Polish with Groq**.

## How it works

```
Sources/
  OrcaNotes/        menu bar app (AppKit lifecycle)
  OrcaNotesCore/    all logic: recording, transcription, cleanup, UI
    AudioRecorder       mic + ScreenCaptureKit capture
    DictationController push-to-talk hotkey, recording, insertion
    LocalTranscriber    WhisperKit wrapper
    LiveCaptioner       chunking, captions, speaker labels
    TextCleanup         offline cleanup rules and per-app styles
    MeetingPipeline     transcript, summary, export
Tests/              XCTest suite
landing/            static landing page
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first. Report security issues as described in [SECURITY.md](SECURITY.md).

## Roadmap

- [ ] Transcript editor and speaker renaming
- [ ] Re-transcribe saved meetings in another language
- [ ] Choice of speech models
- [ ] Notarized releases
- [ ] iOS companion app

## Acknowledgements

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for on-device speech recognition.
- [Groq](https://groq.com) for optional cloud inference.
- Inspired by the product idea behind [FluidVoice](https://github.com/altic-dev/FluidVoice). OrcaNotes is an independent, clean-room project: it contains no FluidVoice code and is not affiliated with or endorsed by its authors.

## License

[MIT](LICENSE) © 2026 Lameda12
