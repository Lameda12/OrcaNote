# Security Policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Report privately through [GitHub Security Advisories](https://github.com/Lameda12/OrcaNote/security/advisories/new). Include what you found, steps to reproduce, and the affected version. You can expect an acknowledgement within a few days.

## Scope and data handling

- Audio and transcripts are stored locally (default `~/MeetingNotes`).
- Speech recognition runs on-device by default. Network calls happen only when you add a Groq key and use cloud features, plus the one-time speech model download from Hugging Face.
- The Groq API key is stored in `~/.orca.env` on your Mac. Treat that file as a secret.
- Dictated text is sent to a cloud provider only if **Polish with Groq** is enabled.
