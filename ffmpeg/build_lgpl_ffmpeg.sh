#!/bin/bash
# Build the STATIC LGPL ffmpeg bundled into PFA Studio — for macOS
# (arm64, native) or for Windows (x86_64, cross-built through mingw-w64).
#
# Produces ffmpeg (macOS) or ffmpeg.exe (Windows) next to this script — a
# self-contained binary that links only system libraries and is
# licensed LGPL 2.1+:
#   * NO --enable-gpl, no x264/x265, no GPL filters
#   * NO --enable-version3, so the terms stay LGPL-2.1 rather than LGPL-3
#   * external codecs: libvorbis + libogg (BSD-3), libopus (BSD-3),
#     libmp3lame (LGPL-2+); flac/aac/pcm encoders are ffmpeg-native
#
# ⚠ WHY THE WINDOWS HALF EXISTS. A Windows binary taken from a third-party
# build service carries dozens of external libraries, --enable-version3
# (which makes it LGPL-3, not the LGPL-2.1 the notice states) and a snapshot
# version string — none of which THIRD-PARTY-LICENSES.txt inside the app
# describes. Building the Windows binary here makes the notice's single
# FFmpeg paragraph true on both platforms with no new license texts at all.
#
# Usage:            bash build_lgpl_ffmpeg.sh                            # macOS
#                   TARGET=windows bash build_lgpl_ffmpeg.sh
# Build dir:        $BUILD_DIR (per target), sources cached in $BUILD_DIR/src —
#                   pre-seed it to skip downloads.
# Prereqs (macOS):  Xcode CLT (clang/make) + pkg-config.
# Prereqs (windows): the same, plus a mingw-w64 toolchain providing
#                   x86_64-w64-mingw32-gcc and nasm, for the x86 assembly the
#                   arm64 mac build never needed
#                   (brew install mingw-w64 nasm).
#
# ⚠ WHAT A CROSS BUILD CANNOT VERIFY. Every check below that RUNS the binary
# — the licence banner, the encoder list, the real encode round-trips — needs
# the target host. For TARGET=windows this script runs the at-rest half
# (configure line read back out of the binary, imports, size) and then says
# out loud that the runtime half is owed, naming the script that answers it.
# It does NOT print a success line it has not earned.
#
# Ship obligations (LGPL): keep THIRD-PARTY-LICENSES.txt + LGPL text in the
# bundle and honour the written source offer for THIS exact tarball set.

set -euo pipefail

TARGET="${TARGET:-macos}"
case "$TARGET" in
    macos)   ;;
    windows) ;;
    *) echo "FATAL: TARGET must be 'macos' or 'windows' (got '$TARGET')" >&2
       exit 1 ;;
esac

FFMPEG_VER=8.1.1
OGG_VER=1.3.6
VORBIS_VER=1.3.7
OPUS_VER=1.5.2
LAME_VER=3.100

# sha256 pins (verified 2026-07-02; lame/vorbis/opus match well-known upstream hashes)
SHA_FFMPEG=b6863adde98898f42602017462871b5f6333e65aec803fdd7a6308639c52edf3
SHA_OGG=83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638
SHA_VORBIS=0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab
SHA_OPUS=65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
SHA_LAME=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$TARGET" = windows ]; then
    HOST_TRIPLE=x86_64-w64-mingw32
    CROSS_PREFIX="$HOST_TRIPLE-"
    BIN_SUFFIX=.exe
    OUT_BIN="${OUT_BIN:-$SCRIPT_DIR/ffmpeg.exe}"
    # Fixed neutral path on purpose: configure bakes build paths into the
    # binary's `configuration:` banner — keep it anonymous and reproducible.
    BUILD_DIR="${BUILD_DIR:-/tmp/pfa-ffmpeg-lgpl-win}"
    command -v "${CROSS_PREFIX}gcc" >/dev/null || {
        echo "FATAL: ${CROSS_PREFIX}gcc not found — install a mingw-w64" >&2
        echo "       toolchain (macOS: brew install mingw-w64)" >&2; exit 1; }
    # x86_64 needs nasm for ffmpeg's hand-written assembly. --disable-x86asm
    # would "work" and quietly ship a slower binary, so ask for the tool
    # instead of degrading behind the builder's back.
    command -v nasm >/dev/null || {
        echo "FATAL: nasm not found — required for the x86 assembly this" >&2
        echo "       target needs (macOS: brew install nasm)" >&2; exit 1; }
else
    HOST_TRIPLE=
    CROSS_PREFIX=
    BIN_SUFFIX=
    OUT_BIN="${OUT_BIN:-$SCRIPT_DIR/ffmpeg}"
    BUILD_DIR="${BUILD_DIR:-/tmp/pfa-ffmpeg-lgpl}"
fi
SRC="$BUILD_DIR/src"
PREFIX="$BUILD_DIR/prefix"
JOBS="$(sysctl -n hw.ncpu)"
# --host makes autotools cross-compile; empty for a native build, and an
# empty --host= is not the same as omitting it, so build the flag as a list.
HOSTFLAG=()
[ -n "$HOST_TRIPLE" ] && HOSTFLAG=(--host="$HOST_TRIPLE")
mkdir -p "$SRC" "$PREFIX"
log_target() { echo "== target: $TARGET${HOST_TRIPLE:+ ($HOST_TRIPLE)}"; }

log() { echo "== $*"; }

fetch() { # fetch <url> <file> <sha256>
    local url="$1" file="$SRC/$2" sha="$3"
    if [ ! -f "$file" ]; then
        log "fetch $2"
        curl -fsSL --retry 3 -o "$file" "$url"
    fi
    echo "$sha  $file" | shasum -a 256 -c - >/dev/null || {
        echo "FATAL: sha256 mismatch for $2" >&2; exit 1; }
}

fetch "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz"                       "ffmpeg-$FFMPEG_VER.tar.xz"   "$SHA_FFMPEG"
fetch "https://downloads.xiph.org/releases/ogg/libogg-$OGG_VER.tar.gz"              "libogg-$OGG_VER.tar.gz"      "$SHA_OGG"
fetch "https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS_VER.tar.gz"     "libvorbis-$VORBIS_VER.tar.gz" "$SHA_VORBIS"
fetch "https://downloads.xiph.org/releases/opus/opus-$OPUS_VER.tar.gz"              "opus-$OPUS_VER.tar.gz"       "$SHA_OPUS"
fetch "https://downloads.sourceforge.net/project/lame/lame/$LAME_VER/lame-$LAME_VER.tar.gz" "lame-$LAME_VER.tar.gz" "$SHA_LAME"

cd "$BUILD_DIR"
for t in "$SRC"/*.tar.*; do
    d="$(tar tf "$t" | head -1 | cut -d/ -f1)"
    [ -d "$d" ] || tar xf "$t"
done

# Older configure scripts (vorbis 2020, lame 2017) predate Apple Silicon —
# refresh their arch-detection helpers from the opus 1.5.x tarball (2024).
for helper in config.guess config.sub; do
    for dest in "libvorbis-$VORBIS_VER" "lame-$LAME_VER"; do
        find "$BUILD_DIR/$dest" -name "$helper" -exec cp "$BUILD_DIR/opus-$OPUS_VER/$helper" {} \;
    done
done

log_target
if [ "$TARGET" = macos ]; then
    export MACOSX_DEPLOYMENT_TARGET=12.0  # the app's minimum macOS version
fi

log "libogg $OGG_VER"
( cd "libogg-$OGG_VER" && ./configure "${HOSTFLAG[@]}" --prefix="$PREFIX" --disable-shared --enable-static >/dev/null && \
  make -j"$JOBS" >/dev/null && make install >/dev/null )

log "libvorbis $VORBIS_VER"
# configure carries a PPC-era -force_cpusubtype_ALL cflag that modern clang
# rejects, which breaks its non-pkg-config ogg probe — strip it and let
# pkg-config find our just-built ogg.
( cd "libvorbis-$VORBIS_VER" && \
  sed -i '' 's/-force_cpusubtype_ALL//g' configure && \
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" ./configure "${HOSTFLAG[@]}" --prefix="$PREFIX" --with-ogg="$PREFIX" \
      --disable-shared --enable-static --disable-examples --disable-docs >/dev/null && \
  make -j"$JOBS" >/dev/null && make install >/dev/null )

log "opus $OPUS_VER"
( cd "opus-$OPUS_VER" && ./configure "${HOSTFLAG[@]}" --prefix="$PREFIX" --disable-shared --enable-static \
      --disable-doc --disable-extra-programs >/dev/null && \
  make -j"$JOBS" >/dev/null && make install >/dev/null )

log "lame $LAME_VER"
( cd "lame-$LAME_VER" && \
  sed -i '' '/lame_init_old/d' include/libmp3lame.sym && \
  ./configure "${HOSTFLAG[@]}" --prefix="$PREFIX" --disable-shared --enable-static \
      --disable-frontend --disable-gtktest >/dev/null && \
  make -j"$JOBS" >/dev/null && make install >/dev/null )

log "ffmpeg $FFMPEG_VER (LGPL configure)"
cd "ffmpeg-$FFMPEG_VER"
# ffmpeg has its own cross-compile switches; autotools' --host means nothing
# here. Everything else is IDENTICAL on both targets on purpose — the notice's
# FFmpeg paragraph describes one configure line, so there had better be one.
CROSSFLAGS=()
PKG_ENV=(PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig")
if [ "$TARGET" = windows ]; then
    # --pkg-config: in cross mode ffmpeg's configure looks for
    # ${cross_prefix}pkg-config and, not finding one, substitutes `false` --
    # after which EVERY library probe fails with "not found using
    # pkg-config" no matter what is installed. Name the host's pkg-config.
    # PKG_CONFIG_LIBDIR (not _PATH): it REPLACES the default search path
    # instead of prepending to it, so a host libopus cannot satisfy a probe
    # for the cross-built one. Cross-compiling against the build machine's
    # own libraries is the classic way to ship a binary that links something
    # nobody meant to ship.
    CROSSFLAGS=(--enable-cross-compile --cross-prefix="$CROSS_PREFIX"
                --arch=x86_64 --target-os=mingw32
                --pkg-config=pkg-config)
    PKG_ENV=(PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig")
    # -static links mingw's own runtime in. Without it the binary imports
    # libwinpthread-1.dll (measured -- the at-rest import check below caught
    # it on the first successful cross build), and the installer ships no
    # such DLL, so ffmpeg would simply fail to start on a user's machine.
    # "Static build" is a claim the notice makes; this is what makes it true.
    EXTRA_LDFLAGS="-L$PREFIX/lib -static"
else
    EXTRA_LDFLAGS="-L$PREFIX/lib"
fi
env "${PKG_ENV[@]}" ./configure \
    "${CROSSFLAGS[@]}" \
    --prefix="$PREFIX" \
    --disable-shared --enable-static \
    --disable-autodetect \
    --disable-doc --disable-debug \
    --disable-ffplay --disable-ffprobe \
    --enable-libvorbis --enable-libopus --enable-libmp3lame \
    --pkg-config-flags=--static \
    --extra-cflags="-I$PREFIX/include" \
    --extra-ldflags="$EXTRA_LDFLAGS" \
    > "$BUILD_DIR/ffmpeg-configure.log"
make -j"$JOBS" >/dev/null

BIN="$BUILD_DIR/ffmpeg-$FFMPEG_VER/ffmpeg$BIN_SUFFIX"
"${CROSS_PREFIX}strip" "$BIN"

# ---------------------------------------------------------------------------
# Verification. Split in two on purpose: what can be read off the binary AT
# REST runs on either target, and what needs to RUN the binary runs only where
# the binary runs. A cross build that printed the runtime checks' success
# lines without executing anything would be the exact defect this project
# keeps finding elsewhere -- a check that cannot answer must say so.
# ---------------------------------------------------------------------------

log "verify (at rest): the configure line, read back out of the binary"
# A static ffmpeg carries its own build recipe as a string, so ask the ARTIFACT
# what is in it rather than trusting the command we just typed. This is the
# check that catches a third-party binary long before a legal document does.
CONFIG_LINE="$(strings -a "$BIN" | grep -m1 -- '--enable-libvorbis' || true)"
[ -n "$CONFIG_LINE" ] || { echo "FATAL: no configure string in the binary" >&2; exit 1; }
echo "$CONFIG_LINE" > "$BUILD_DIR/ffmpeg-configuration.txt"

for forbidden in --enable-gpl --enable-version3 --enable-nonfree; do
    case "$CONFIG_LINE" in
        *"$forbidden"*) echo "FATAL: $forbidden present in the shipped binary's own configure line" >&2; exit 1 ;;
    esac
done

# Exactly the external libraries the notice names, and nothing else. An
# --enable-lib* the notice does not list is the third-party-binary defect
# arriving from our own side, so it fails here rather than in a legal document.
UNEXPECTED="$(echo "$CONFIG_LINE" | tr ' ' '\n' | grep -E '^--enable-(lib|lib)' \
    | grep -vE '^--enable-(libvorbis|libopus|libmp3lame)$' || true)"
if [ -n "$UNEXPECTED" ]; then
    echo "FATAL: external libraries the notice does not name:" >&2
    echo "$UNEXPECTED" >&2; exit 1
fi
for want in --enable-libvorbis --enable-libopus --enable-libmp3lame; do
    case "$CONFIG_LINE" in
        *"$want"*) ;;
        *) echo "FATAL: $want missing from the shipped binary" >&2; exit 1 ;;
    esac
done
log "  configure line: 3 external libraries, no gpl/version3/nonfree"

log "verify (at rest): no foreign library is linked dynamically"
if [ "$TARGET" = windows ]; then
    # A PE binary names its imports. Only Windows' own DLLs are acceptable:
    # libgcc_s_seh-1.dll or libwinpthread-1.dll here would mean the binary
    # needs mingw runtime DLLs beside it, which the installer does not ship.
    SYSTEM_DLLS='^(ADVAPI32|BCRYPT|KERNEL32|USER32|GDI32|SHELL32|OLE32|OLEAUT32|WS2_32|SECUR32|PSAPI|IMM32|VERSION|MSVCRT|api-ms-win-[a-z0-9-]+|ucrtbase|dwmapi|SETUPAPI|CFGMGR32|WINMM|AVICAP32|MFPLAT|STRMIIDS|UUID|d3d11|dxgi|mfuuid|SHLWAPI|CRYPT32|NETAPI32|USERENV|IPHLPAPI|POWRPROF|DBGHELP)\.(dll|DLL)$'
    FOREIGN="$("${CROSS_PREFIX}objdump" -p "$BIN" | awk '/DLL Name:/ {print $3}' \
        | grep -vEi "$SYSTEM_DLLS" || true)"
    if [ -n "$FOREIGN" ]; then
        echo "FATAL: non-system DLL imported (see below)" >&2
        echo "$FOREIGN" >&2; exit 1
    fi
    log "  imports: $("${CROSS_PREFIX}objdump" -p "$BIN" | grep -c 'DLL Name:') system DLLs, none foreign"
else
    if otool -L "$BIN" | tail -n +2 | grep -vE '^\s+(/usr/lib/|/System/Library/)'; then
        echo "FATAL: non-system dylib linked (see above)" >&2; exit 1
    fi
    log "  links system frameworks only"
fi

if [ "$TARGET" = windows ]; then
    cp "$BIN" "$OUT_BIN"
    chmod +x "$OUT_BIN"
    log "DONE (cross-built) → $OUT_BIN ($(du -h "$OUT_BIN" | cut -f1 | tr -d ' '))"
    log "build tree left at $BUILD_DIR (safe to delete)"
    cat <<'OWED'

⚠ THE RUNTIME HALF IS NOT DONE, AND THIS SCRIPT DID NOT DO IT.
   Cross-built here, so nothing on this host executed the binary. Still owed,
   on a Windows machine, before this binary ships:

       py -3 verify_ffmpeg_runtime.py

   It runs exactly the checks the macOS path runs natively -- the LGPL banner,
   the encoder set the app's converter calls, and a real encode round-trip
   per shipped format. Until it has passed on Windows, this binary is BUILT,
   not VERIFIED, and the difference is the whole reason the notice was wrong
   in the first place.
OWED
    exit 0
fi

log "verify: license banner"
"$BIN" -L 2>/dev/null | head -3
"$BIN" -L 2>/dev/null | head -5 | grep -qi 'Lesser General Public' || {
    echo "FATAL: banner does not say Lesser GPL" >&2; exit 1; }

log "verify: encoders the app calls"
ENC="$("$BIN" -hide_banner -encoders 2>/dev/null)"
for e in libvorbis libopus libmp3lame flac aac pcm_s16le pcm_s24le pcm_s32le pcm_s16be pcm_s24be pcm_s32be; do
    echo "$ENC" | grep -q " $e " || { echo "FATAL: encoder $e missing" >&2; exit 1; }
done

log "verify: real encode round-trips"
T="$BUILD_DIR/enc-test"; mkdir -p "$T"
"$BIN" -hide_banner -loglevel error -f lavfi -i "sine=frequency=440:duration=1" -ac 2 "$T/in.wav"
for spec in "ogg:libvorbis" "opus:libopus" "mp3:libmp3lame" "flac:flac" "m4a:aac" "wav:pcm_s24le" "aiff:pcm_s16be"; do
    ext="${spec%%:*}"; codec="${spec##*:}"
    "$BIN" -hide_banner -loglevel error -y -i "$T/in.wav" -c:a "$codec" "$T/out.$ext"
    "$BIN" -hide_banner -loglevel error -i "$T/out.$ext" -f null - || {
        echo "FATAL: $ext round-trip failed" >&2; exit 1; }
done

cp "$BIN" "$OUT_BIN"
chmod +x "$OUT_BIN"
log "DONE → $OUT_BIN ($(du -h "$OUT_BIN" | cut -f1 | tr -d ' '))"
log "build tree left at $BUILD_DIR (safe to delete)"
