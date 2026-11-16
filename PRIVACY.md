# OrcaNotes Privacy Policy

_Last updated: November 16, 2026_

OrcaNotes ("the app") is a meeting-notes and dictation app for iPhone, iPad and Mac. It is built to work on your device. This policy explains what happens to your data.

## The short version

- **We do not collect your data.** The developer has no servers, no accounts, no analytics, no ads and no tracking.
- **Your recordings, transcripts and notes stay on your device** unless you choose a cloud option or share them yourself.
- **Nothing is sold or shared** for advertising.

## What the app handles, and where it goes

| Data | Where it is processed | Where it is stored |
|---|---|---|
| Microphone audio (and on Mac, system audio of a call you choose to record) | On your device | Not kept after transcription, unless you export it |
| Transcripts and notes | On your device | In the app's folder (iPhone: Files → On My iPhone → OrcaNotes; Mac: the folder you choose) |
| Summaries | On your device (Apple Intelligence, an open model, or Ollama on Mac), or Groq if you turn it on | With your notes |
| Groq API key (optional) | – | The device Keychain (iOS) or local settings (Mac) |
| App settings | – | On your device |

### Optional cloud processing (Groq)

Summaries are made on your device by default. If you choose **Groq (cloud)** as the provider and enter your own Groq API key, the transcript text needed for that request (and, on Mac, audio for cloud transcription if you use it) is sent to Groq, Inc. to generate the result. That request is between you and Groq under your Groq account and [Groq's privacy policy](https://groq.com/privacy-policy/). The developer never receives it. You can switch back to an on-device provider at any time.

### Model downloads

Speech models and open AI models are downloaded from Hugging Face the first time you use them. Like any download, Hugging Face receives your IP address and standard request information, under [Hugging Face's privacy policy](https://huggingface.co/privacy). No transcripts or notes are sent. After download, the models run offline.

### Apple

Apple Intelligence runs on your device. If you use iCloud backups or iCloud Drive, Apple stores those copies under [Apple's privacy policy](https://www.apple.com/legal/privacy/). Downloaded AI models are excluded from backups.

## Permissions

- **Microphone**: to transcribe your dictation and meetings.
- **Mac only: Screen & System Audio Recording**: to capture the other side of a call you choose to record.
- **Mac only: Accessibility**: to paste dictated text into the app you are using.

You can turn these off at any time in Settings. The app keeps working with reduced features.

## Recording other people

Recording laws differ by place. Many US states, Canada, the EU and the UK require some or all participants to agree before a conversation is recorded. **You are responsible for telling people and getting their consent before you record them.**

## Deleting your data

Because your data is only on your device, you control it:

- Delete a note in the app or in the Files app.
- Delete downloaded models in Settings → Downloaded models.
- Uninstalling the app removes its data from the device (copies in your own backups or iCloud Drive follow Apple's settings).

There is no account to delete and nothing for us to erase on a server.

## Your rights (GDPR, UK GDPR, CCPA/CPRA, PIPEDA and similar laws)

You have rights to access, correct, delete and port your personal data, and to object to or restrict processing. Since the developer does not collect or hold personal data from the app, there is normally nothing we can access or delete; you can exercise these rights directly on your device. We do not sell or share personal information, and we do not use it for targeted advertising or profiling. If you have a question or a complaint, contact us (below). You can also complain to your local data protection authority.

## Children

OrcaNotes is a general productivity app and is not directed at children under 13 (or the age of digital consent where you live). The developer does not knowingly collect personal data from children.

## Security

Data stays in the app's sandbox on your device, protected by your device passcode and Apple's encryption. Network requests (model downloads, Groq) use HTTPS.

## Changes

If this policy changes, we will update the date above and publish the new version in the [source repository](https://github.com/Lameda12/OrcaNote/blob/main/PRIVACY.md), where every past version is visible in the history.

## Contact

Questions or requests: open an issue at <https://github.com/Lameda12/OrcaNote/issues>. For security issues, see [SECURITY.md](SECURITY.md).
