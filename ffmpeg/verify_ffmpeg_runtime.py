"""The half of build_lgpl_ffmpeg.sh's verification that has to RUN the binary.

The Windows ffmpeg is cross-built on the mac through mingw-w64, so the build
host can read the binary but cannot execute it. Everything checkable at rest -- the configure line read back out of the
binary, the absence of --enable-gpl / --enable-version3, the external library
set, the imported DLLs -- runs there and fails the build. Everything that
needs the binary to actually run is here, and until this passes on a Windows
machine the binary is BUILT, not VERIFIED.

These are the same checks the macOS path runs natively, in the same order and
with the same fatal conditions:

  * the LGPL banner the binary prints about itself;
  * every encoder the app's converter calls;
  * a real encode round-trip per shipped format, decoded back.

Run on Windows, against a freshly built binary next to this script:

    py -3 verify_ffmpeg_runtime.py

or against an installed copy:

    py -3 verify_ffmpeg_runtime.py "%LOCALAPPDATA%\\Programs\\PFA Studio\\_internal\\ffmpeg.exe"

Exit code is 0 only when every check passed. A check that could not run is a
failure, never a silent skip.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "ffmpeg.exe" if os.name == "nt" else "ffmpeg")

# The app's converter calls exactly these.
ENCODERS = ("libvorbis", "libopus", "libmp3lame", "flac", "aac",
            "pcm_s16le", "pcm_s24le", "pcm_s32le",
            "pcm_s16be", "pcm_s24be", "pcm_s32be")

# (container, codec) pairs the exporter writes.
ROUND_TRIPS = (("ogg", "libvorbis"), ("opus", "libopus"), ("mp3", "libmp3lame"),
               ("flac", "flac"), ("m4a", "aac"), ("wav", "pcm_s24le"),
               ("aiff", "pcm_s16be"))

# What the at-rest half already refused, asserted again from the running
# binary: the two halves must not be able to disagree about the same string.
FORBIDDEN = ("--enable-gpl", "--enable-version3", "--enable-nonfree")
REQUIRED = ("--enable-libvorbis", "--enable-libopus", "--enable-libmp3lame")


def run(binary, *args, **kw):
    return subprocess.run([binary] + list(args), capture_output=True,
                          text=True, encoding="utf-8", errors="replace", **kw)


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    if not os.path.isfile(binary):
        print("FATAL: no binary at " + binary)
        return 1
    problems = []
    print("verify_ffmpeg_runtime: " + binary)

    proc = run(binary, "-version")
    if proc.returncode != 0:
        print("FATAL: the binary does not run here:\n" + proc.stderr.strip())
        return 1
    version_line = proc.stdout.splitlines()[0] if proc.stdout else ""
    print("  " + version_line)

    config = [ln for ln in proc.stdout.splitlines()
              if ln.startswith("configuration:")]
    if not config:
        problems.append("the binary prints no configuration line")
    else:
        for flag in FORBIDDEN:
            if flag in config[0]:
                problems.append(flag + " is present in the running binary")
        for flag in REQUIRED:
            if flag not in config[0]:
                problems.append(flag + " is missing from the running binary")
        extra = [w for w in config[0].split()
                 if w.startswith("--enable-lib") and w not in REQUIRED]
        if extra:
            problems.append("external libraries the notice does not name: "
                            + " ".join(extra))

    banner = run(binary, "-L").stdout
    if "lesser general public" not in banner.lower():
        problems.append("the licence banner does not say Lesser GPL -- "
                        "it says: " + " ".join(banner.split()[:12]))

    listed = run(binary, "-hide_banner", "-encoders").stdout
    for enc in ENCODERS:
        if (" " + enc + " ") not in listed:
            problems.append("encoder " + enc + " missing")

    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.wav")
        made = run(binary, "-hide_banner", "-loglevel", "error", "-f", "lavfi",
                   "-i", "sine=frequency=440:duration=1", "-ac", "2", src)
        if made.returncode != 0 or not os.path.isfile(src):
            problems.append("could not synthesise the test tone: "
                            + made.stderr.strip()[:200])
        else:
            for ext, codec in ROUND_TRIPS:
                out = os.path.join(tmp, "out." + ext)
                enc = run(binary, "-hide_banner", "-loglevel", "error", "-y",
                          "-i", src, "-c:a", codec, out)
                if enc.returncode != 0:
                    problems.append(ext + " encode failed: "
                                    + enc.stderr.strip()[:200])
                    continue
                dec = run(binary, "-hide_banner", "-loglevel", "error",
                          "-i", out, "-f", "null", "-")
                if dec.returncode != 0:
                    problems.append(ext + " decoded back with an error: "
                                    + dec.stderr.strip()[:200])

    print()
    if problems:
        print("VERDICT: FAIL -- %d problem(s)" % len(problems))
        for p in problems:
            print("  - " + p)
        return 1
    print("VERDICT: ok -- banner, %d encoders and %d round-trips, on this host"
          % (len(ENCODERS), len(ROUND_TRIPS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
