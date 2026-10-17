#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - the title's music, from the game's disc.
#
#   ps5/art/make-title-music.sh [DISC]     (default: the GEDP01 or GEDE01 disc in dump/)
#
#   audio/music/inscath.adp  ->  ps5/sce_sys/snd0.at9   what plays while the tile is
#                                                       highlighted on the home screen
#
# The first 30 s of one of the game's insanity themes (Gary's pick), faded out over the
# last 3 s so the loop comes back into its quiet opening without a jump, at -28 LUFS
# (written to pubtools.loudnessSnd0 in param.json). It is the game's own music, so like
# the disc it is never committed: run this after cloning, before ps5/tools/build.sh.
# Needs FFmpeg (for the disc's ADP audio) and ps5-at9-converter
# (github.com/blackbearreloaded/ps5-at9-converter, beside this repo or at
# $PS5_AT9_CONVERTER), which needs numpy.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
art=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ps5=$(dirname "$art")
root=$(dirname "$ps5")
disc=${1:-}
if [[ -z $disc ]]; then
    for disc in "$root"/dump/GEDP01.iso "$root"/dump/GEDE01.iso; do [[ -f $disc ]] && break; done
fi
[[ -f $disc ]] || { echo "no disc: put GEDP01.iso or GEDE01.iso in dump/, or name one" >&2; exit 2; }
converter=${PS5_AT9_CONVERTER:-$root/../ps5-at9-converter}
[[ -f $converter/ps5_at9.py ]] || { echo "no ps5-at9-converter at $converter" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# One file out of the disc's file table (FST).
python3 - "$disc" audio/music/inscath.adp "$work/inscath.adp" <<'PY'
import struct, sys
disc, want, out = sys.argv[1:]
with open(disc, "rb") as f:
    f.seek(0x424)
    fst_off, fst_size = struct.unpack(">II", f.read(8))
    f.seek(fst_off)
    fst = f.read(fst_size)
    count = struct.unpack_from(">I", fst, 8)[0]
    names = fst[count * 12:]
    stack = [(count, "")]
    for i in range(1, count):
        while i >= stack[-1][0]:
            stack.pop()
        word, a, b = struct.unpack_from(">III", fst, i * 12)
        o = word & 0xFFFFFF
        path = (stack[-1][1] + "/" + names[o:names.index(b"\0", o)].decode()).lstrip("/")
        if word >> 24:
            stack.append((b, path))
        elif path == want:
            f.seek(a)
            open(out, "wb").write(f.read(b))
            break
    else:
        sys.exit(f"{want} is not on {disc}")
PY
ffmpeg -hide_banner -loglevel error -y -i "$work/inscath.adp" -c:a pcm_s16le "$work/inscath.wav"
python3 -I "$converter/ps5_at9.py" -i "$work/inscath.wav" -o "$ps5/sce_sys/snd0.at9" \
    --duration 30 --fade-out 3 --param-json "$ps5/sce_sys/param.json"
