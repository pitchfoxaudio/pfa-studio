# PFA Studio

**PFA Studio** is the authoring app of the PitchFox Audio suite — a DAW-style
editor for building adaptive music and SFX for games. You author events,
tracks, variations, transitions, node graphs, spatial settings and reverb
zones, then export a single `config.json` (+ audio) that plays back
on both PFA Engine runtimes:

- [pfa-engine-js](https://github.com/pitchfoxaudio/pfa-engine-js) — web games (Web Audio API, MIT)
- [pfa-engine-godot](https://github.com/pitchfoxaudio/pfa-engine-godot) — Godot 4 addon (MIT)

This repository hosts **releases and the public issue tracker** for PFA Studio.

## Download

Builds are published under [Releases](../../releases/latest). Each release
carries one file per platform:

| Platform | File |
|---|---|
| macOS, Apple Silicon (arm64) | `PFA-Studio-<version>-b<build>.zip` |
| Windows, 64-bit | `PFA-Studio-Setup-<version>-b<build>-win64.exe` |

Tested on macOS 26 (Tahoe) and macOS 27.0.1 on Apple Silicon and on Windows 10 (22H2).

PFA Studio is in public beta and **free to download and use during the beta,
commercial projects included**. The full terms are the Beta License (EULA):
it is shown on first launch and stays one click away under
**Help → Beta License (EULA)**.

## First launch on macOS

Beta builds are ad-hoc signed (no Apple Developer ID yet), so macOS treats
the downloaded app as unverified.

1. Unzip.
2. Move `PFA Studio.app` to Applications (optional — it runs from anywhere).
3. Double-click to launch. The first time, macOS stops the app with
   **"PFA Studio" Not Opened** — click **Done** (not Move to Bin).
4. Open **System Settings → Privacy & Security** and scroll to
   **Security**: next to *"PFA Studio" was blocked to protect your Mac*,
   click **Open Anyway**.
5. macOS asks once more — **Open "PFA Studio"?** — click **Open Anyway**
   (and confirm with your password or Touch ID if asked).

This is needed once per build — a new version asks again; afterwards it
opens normally.

Terminal alternative:
`xattr -dr com.apple.quarantine "/Applications/PFA Studio.app"`

## First launch on Windows

1. Download and run `PFA-Studio-Setup-<version>-b<build>-win64.exe`. It
   installs for the current user (no administrator rights needed) and
   associates `.pfa` project files on the way.
2. Launch **PFA Studio** from the Start Menu. Beta builds are not
   code-signed, so SmartScreen may show "Windows protected your PC" —
   choose **More info → Run anyway** once.

On Windows 11 with **Smart App Control** on, Windows blocks unsigned
installers and has no way to allow a single app. Installing means turning it
off under **Windows Security → App & browser control → Smart App Control
settings**; recent Windows updates let you turn it back on later without
reinstalling Windows.

## Documentation

- **User manual** — https://pitchfoxaudio.github.io/docs/ (the same manual
  ships inside the app: **Help → Manual (PDF)**)

## Community

Questions, bug reports and ideas are welcome on the PitchFox Audio Discord:
https://discord.gg/bxSRupPCPS

## Updates

Once a day, on launch, the app asks this repository's Releases feed whether a
newer version is out and shows the release notes when one is. It is a plain
anonymous HTTPS request; nothing is downloaded or installed automatically,
and the check can be turned off in the app (**⚙ → Info**).

## Bundled FFmpeg (LGPL)

The app bundles FFmpeg binaries built under the LGPL. The complete build kit
for those exact binaries — the source route the in-app notice names — lives
in [`ffmpeg/`](ffmpeg/). All third-party license texts ship inside the app
(**Help → Third-Party Licenses**).

## Reporting bugs

Post in **#bug-reports** on [Discord](https://discord.gg/bxSRupPCPS), open an
[issue](../../issues), or write to info@pitchfoxaudio.com (the place for
project files you can't share publicly) — **Help → Report a Bug…** in the app
shows the address together with the build line to paste. Include your OS
version, what you did and what you expected, and the crash log if there is
one:

- macOS: `~/Library/Logs/PFA Studio/crash_log.txt`
- Windows: `%LOCALAPPDATA%\PFA Studio\Logs\crash_log.txt`
