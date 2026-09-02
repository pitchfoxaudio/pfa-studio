# Bundled ffmpeg

This folder is the complete build kit for the FFmpeg binaries inside PFA
Studio: the macOS one at `Contents/Frameworks/ffmpeg` and the Windows one at
`_internal\ffmpeg.exe`. It is published at
https://github.com/pitchfoxaudio/pfa-studio/tree/main/ffmpeg so that anyone
who receives a build can obtain the corresponding source set: the script
fetches every upstream tarball by URL and sha256 (FFmpeg, libogg, libvorbis,
libopus, LAME), builds them with one configure line, and verifies the result.
No upstream source is modified. The kit itself (the script and its two
helpers) is released under the MIT License; the binaries it produces are
LGPL-2.1-or-later, as the notice inside the app says.

Two binaries, both built by the same script from the same sha256-pinned
tarballs. They ship inside the app; they are not part of this kit:

| file | target | built |
|---|---|---|
| `ffmpeg` | macOS arm64 | natively |
| `ffmpeg.exe` | Windows x86_64 | cross-built through mingw-w64 |

The app bundles the host's one at its payload root, which is where the
converter looks first when frozen.

⚠ **Why both binaries come from this one script.** A Windows binary taken
from a third-party build service carries dozens of external libraries, a
`--enable-version3` switch that turns the terms into LGPL-3, and a snapshot
version string — none of which the notice inside the app describes. Building
both binaries here keeps the notice's single FFmpeg paragraph true on both
platforms with no extra licence texts, and keeps the Windows binary at about
30 MB.

This folder is the source route the LGPL asks for, not a second copy of
the binaries: the shipped binary is the one inside the app, and the build
checks compare it with the build it was made from.

## Requirements for the binary

- Static: only system libraries. macOS — nothing outside `/usr/lib` or
  `/System/Library` in `otool -L`. Windows — no DLL import outside the
  Windows system set; `libwinpthread-1.dll` showed up on the first successful
  cross build and is why `-static` is in the link flags.
- Exactly three external libraries (`libvorbis`, `libopus`, `libmp3lame`;
  libogg rides in with vorbis), and no `--enable-gpl` / `--enable-version3` /
  `--enable-nonfree`. All six facts are read back out of the binary's own
  configure string by the build script, and again by the release checks
  that clear every artifact before it ships.
- Encoders the app's exporter actually calls: `libvorbis`, `libopus`, `libmp3lame`,
  `flac`, `pcm_s16le/24/32`, `aac`.

## Ship binaries — build them here

```
brew install pkg-config                       # build-time tool, one-off
bash build_lgpl_ffmpeg.sh                     # -> ffmpeg (macOS arm64)

brew install mingw-w64 nasm                   # cross toolchain + x86 assembler
TARGET=windows bash build_lgpl_ffmpeg.sh                    # -> ffmpeg.exe
```

The macOS build self-verifies completely: LGPL banner, no non-system dylibs,
every encoder the exporter calls, and real encode round-trips per format.

⚠ **The Windows build cannot finish its own verification, and says so.** It is
cross-built, so this host can read the binary but not run it. The at-rest half
(configure line, forbidden switches, external library set, imported DLLs) runs
and fails the build; the half that needs to execute the binary is owed on a
Windows machine:

```
py -3 verify_ffmpeg_runtime.py
```

That script runs exactly the macOS path's runtime checks and is part of the
release checklist's Windows half. Until it passes, `ffmpeg.exe` is
BUILT, not VERIFIED — and the distance between those two words is the whole
reason the notice was wrong for as long as it was.

LGPL obligations are covered by `THIRD-PARTY-LICENSES.txt` + `licenses/`
(bundled into both artifacts) — keep the script's tarball set reproducible so
the written source offer stays honest.

History: an early packaging experiment used a GPL-configured build from
https://ffmpeg.martin-riedl.de; it was replaced by the script build above
before any build shipped — never ship a GPL binary.
