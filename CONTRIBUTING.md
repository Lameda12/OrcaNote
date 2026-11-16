# Contributing to OrcaNotes

Thanks for helping. Bug reports, ideas, docs and code are all welcome.

## Ground rules

- Be kind. Everyone must follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- **Clean-room only.** Do not copy code from GPL or otherwise incompatible projects (including FluidVoice). Write your own implementation from behavior and public documentation. PRs that include copied code will be closed.
- Privacy is a feature. No telemetry, no new network calls, and no cloud features that are on by default.

## Getting started

Requires macOS 14+ and Xcode 15+.

```bash
git clone https://github.com/Lameda12/OrcaNote.git
cd OrcaNote
swift build      # debug build
make test        # run tests
make app         # build build/OrcaNotes.app
```

## Making a change

1. Open an issue first for anything larger than a small fix, so we can agree on the approach.
2. Fork the repo and create a branch: `feat/short-name` or `fix/short-name`.
3. Keep changes focused. One topic per pull request.
4. Add or update tests. Logic that can be a pure function should be one, with unit tests (see `TextCleanup` and `CaptionLogic`).
5. Run `make test` and make sure `swift build -c release --arch arm64 --arch x86_64` still succeeds.
6. Update `README.md` and `CHANGELOG.md` when behavior changes.
7. Open a pull request using the template.

## Style

- Follow the existing Swift style and the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Prefer small files with a single responsibility. Put logic in `OrcaNotesCore`, not in `OrcaNotes`.
- UI and audio code run on the main actor or a dedicated queue. Do not block the main thread.
- No force-unwraps in new code unless a failure is impossible and commented.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.

## What is hard to test

Permission prompts, global hotkeys, pasting into other apps and system-audio capture need a real Mac. In your PR, say how you tested those by hand.

## License

By contributing, you agree your work is released under the [MIT License](LICENSE).
