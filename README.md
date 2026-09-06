# PFA Studio

**PFA Studio** is the authoring app of the PitchFox Audio suite — a DAW-style
editor for building adaptive music and SFX for games. You author events,
tracks, variations, transitions, node graphs, spatial settings and reverb
zones, then export a single `config.json` (+ audio) that plays back
on both PFA Engine runtimes:

- [pfa-engine-js](https://github.com/pitchfoxaudio/pfa-engine-js) — web games (Web Audio API, MIT)
- [pfa-engine-godot](https://github.com/pitchfoxaudio/pfa-engine-godot) — Godot 4 addon (MIT)

This repository hosts **releases and the public issue tracker** for PFA Studio.

## Documentation

- **User manual** — https://pitchfoxaudio.github.io/docs/ (also available
  there as a single PDF)

## Download

The beta has not started yet — builds will appear under
[Releases](../../releases). Join the beta list at
[pitchfoxaudio.com/pfa-studio](https://pitchfoxaudio.com/pfa-studio).

PFA Studio is free to download and use during the beta.

## Requirements

- macOS, Apple Silicon (arm64). A Windows build is planned after the beta.

## First launch on macOS

Beta builds are ad-hoc signed (no Apple Developer ID yet), so Gatekeeper
flags the downloaded app. This is expected — first launch:

1. Unzip.
2. Move `PFA Studio.app` to Applications (optional — it runs from anywhere).
3. **Right-click (Ctrl-click) the app → Open → Open.**
   A plain double-click shows "cannot be opened" — the right-click route
   offers the Open button. Needed once; afterwards it opens normally.

Terminal alternative:
`xattr -dr com.apple.quarantine "/Applications/PFA Studio.app"`

## Reporting bugs

Open an [issue](../../issues) — include your macOS version, what you did,
what you expected, and the crash log from `~/Library/Logs/PFA Studio/` if any.
