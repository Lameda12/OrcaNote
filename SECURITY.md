# Security Policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report privately through [GitHub Security Advisories](https://github.com/Lameda12/OrcaNote/security/advisories/new). Include what you found, steps to reproduce, and the affected version. You can expect an acknowledgement within a few days.

## Scope and data handling

- Audio and transcripts are stored locally (default `~/MeetingNotes`).
- Speech recognition and AI summaries run on-device by default. Network calls: one-time model downloads (Whisper from Hugging Face, LLMs through Ollama), requests to Ollama on `127.0.0.1:11434`, and Groq only when you pick it as the provider.
- The Groq API key is stored in `~/.orca.env` on your Mac. Treat that file as a secret.
- Dictated text is sent to the cloud only if **AI polish** is on and the provider is Groq.
