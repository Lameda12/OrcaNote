<p align="center">
  <img src="assets/logo.png" alt="OrcaNotes logo" width="140" height="140">
</p>

<h1 align="center">OrcaNotes</h1>

<p align="center">
  <b>Private dictation and meeting notes for Mac, iPhone and iPad.</b><br>
  Speak into any app, record calls with live captions, and keep every word on your Mac.
</p>

<p align="center">
  <a href="https://github.com/Lameda12/OrcaNote/actions/workflows/ci.yml"><img src="https://github.com/Lameda12/OrcaNote/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20iOS%2017%2B-lightgrey.svg" alt="macOS 14+ and iOS 17+">
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
| **Choose your speech model** | Six free Whisper models, from Tiny (75 MB, fastest) to Large v3 Turbo (632 MB, 99 languages). Switch in settings; the new model downloads automatically. |
| **Free local AI summaries** | Meeting summaries, decisions and action items written on your Mac by open models (Llama 3.2, Qwen 2.5, Gemma 3) through [Ollama](https://ollama.com). No key, no cloud. |
| **Structured notes** | Saved as Markdown with `.txt` and `.json` transcripts. |
| **Privacy first** | No account, no telemetry, no cloud storage. Everything runs on-device by default; Groq is an optional cloud alternative. |
| **Universal app** | One build for Apple Silicon and Intel Macs. |

## iPhone and iPad

The iOS app (in [`iOS/`](iOS)) shares the same core and runs fully on-device:

- **Meeting mode**: record in-person meetings with live captions, then get an on-device transcript and summary.
- **Dictate mode**: speak, pick a style, and the cleaned text is copied to the clipboard (or shared).
- **Apple Intelligence summaries**: free and private on iOS 26 devices that support it; Groq is optional.
- **Open models on the phone**: download a small open model and summarize with no account and no cloud (see below).
- Notes are saved as Markdown in **Files → On My iPhone → OrcaNotes**.

iOS does not let apps record other apps' audio or type into other apps, so on iPhone meetings are recorded with the microphone, and dictated text goes to the clipboard.

Build it:

```bash
brew install xcodegen
xcodebuild -downloadComponent MetalToolchain   # once; needed to build MLX
cd iOS
xcodegen generate
open OrcaNotesiOS.xcodeproj
```

To run on a device, create `iOS/Signing.local.xcconfig` (gitignored) with `DEVELOPMENT_TEAM = <your team ID>`.

### Open models on iPhone and iPad

In **Settings → Summaries**, choose **Open model on device**, pick a model and tap **Download**. Models are 4-bit [MLX](https://github.com/ml-explore/mlx-swift-lm) builds from [mlx-community](https://huggingface.co/mlx-community) on Hugging Face. They are stored privately in the app (not in Files, not backed up), and you can swipe to delete them.

| Model | Download | License |
|---|---|---|
| Qwen3 1.7B (default) | 0.98 GB | Apache 2.0 |
| Gemma 3 1B | 0.77 GB | Gemma Terms of Use |
| Llama 3.2 1B | 0.71 GB | Llama 3.2 Community License |
| Qwen3.5 2B | 1.75 GB | Apache 2.0, newer phones (8 GB RAM) |

Open models need a real device; MLX does not run in the iOS Simulator. Small models can get details wrong, so review summaries before sharing them.

## Install (Mac)

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

## Free AI models

Everything below is free and open, and runs on your Mac. Open **⚙︎ Settings → Free AI Models** in the menu bar popover.

### Speech-to-text (built in)

| Model | Size | Languages |
|---|---|---|
| Tiny | 75 MB | English |
| Base (default) | 145 MB | English |
| Small | 480 MB | English |
| Base | 145 MB | 99 languages |
| Small | 480 MB | 99 languages |
| Large v3 Turbo | 632 MB | 99 languages, most accurate |

OpenAI Whisper (MIT license), converted to Core ML by [Argmax](https://huggingface.co/argmaxinc/whisperkit-coreml). Downloaded once from Hugging Face, then works offline.

### Summaries and AI polish (via Ollama)

1. Install [Ollama](https://ollama.com/download) (free) and open it.
2. In OrcaNotes settings, set **Summaries & polish** to **On-device (Ollama)**.
3. Pick a model and click **Download**:

| Model | Size | Notes |
|---|---|---|
| Llama 3.2 3B (default) | 2.0 GB | Good balance for most Macs |
| Qwen 2.5 3B | 1.9 GB | Strong multilingual |
| Gemma 3 4B | 3.3 GB | |
| Qwen 2.5 7B | 4.7 GB | Best quality, 16 GB RAM recommended |

Any other model you already have in Ollama also shows up. Long meetings are summarized in parts so they fit a small model's context window.

### Optional: Groq (cloud)

Prefer the cloud? Choose **Groq (cloud)** and paste a free [Groq API key](https://console.groq.com/keys), or copy `.env.example` to `.env`. Transcripts are then sent to Groq for summaries.

## How it works

```
Sources/
  OrcaNotes/        menu bar app (AppKit lifecycle)
  OrcaNotesCore/    all logic: recording, transcription, cleanup, UI
    AudioRecorder       mic + ScreenCaptureKit capture
    DictationController push-to-talk hotkey, recording, insertion
    LocalTranscriber    WhisperKit wrapper, model switching
    ModelCatalog        free speech models and local LLMs
    LLMClient           Ollama (local) and Groq (cloud) chat
    ModelsCard          model settings UI and downloads
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
- [x] Choice of speech models
- [x] Free local AI summaries
- [ ] Notarized releases
- [x] iOS app
- [ ] iOS keyboard for dictating into other apps

## Acknowledgements

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for on-device speech recognition.
- [Ollama](https://ollama.com) and the open model authors (Meta Llama, Alibaba Qwen, Google Gemma) for local AI.
- [Groq](https://groq.com) for optional cloud inference.
- Inspired by the product idea behind [FluidVoice](https://github.com/altic-dev/FluidVoice). OrcaNotes is an independent, clean-room project: it contains no FluidVoice code and is not affiliated with or endorsed by its authors.

## License

[MIT](LICENSE) © 2026 Lameda12
