#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - the title's art, from the pictures in this folder.
#
#   ps5/art/make-title-art.sh
#
#   icon0-source.png  ->  ps5/sce_sys/icon0.png   the home-screen tile, 512x512
#   pic-source.png    ->  ps5/sce_sys/pic0.dds    the background behind the title, 3840x2160
#                     ->  ps5/sce_sys/pic1.dds    the splash while it starts
#
# Both pictures are the port's own, nothing in them is from the game: the icon (an eclipse
# over a ring of standing stones) made with ChatGPT, the background (a black planet in a
# broken arch over a drowned city of impossible stairs) with Google's Gemini image model.
# The background keeps its subject out of what the home screen covers: the top quarter
# (menu bar and tile row) and the left third (title, Play Game, Friends Who Play).
# Needs Python with Pillow and numpy.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
art=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ps5=$(dirname "$art")
python3 - "$art/icon0-source.png" "$ps5/sce_sys/icon0.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").resize((512, 512), Image.LANCZOS).save(sys.argv[2])
PY
python3 "$ps5/tools/png-to-title-dds.py" "$art/pic-source.png" "$ps5/sce_sys/pic0.dds"
cp "$ps5/sce_sys/pic0.dds" "$ps5/sce_sys/pic1.dds"
ls -l "$ps5/sce_sys"
