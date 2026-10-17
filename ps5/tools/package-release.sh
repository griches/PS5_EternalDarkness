#!/usr/bin/env bash
# Zip dist/PPSA99314/ as a ready-made release: the title as it is on the
# console, with an empty dump/ where the player puts their disc image. Nothing
# from the game goes in (the title reads main.dol from the disc on its first
# start); this checks that before zipping.
#
#   ps5/tools/package-release.sh [version]   -> dist/EternalDarkness-PS5-<version>.zip
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
title=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$root/ps5/sce_sys/param.json")
version=${1:-$(python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))["contentVersion"]; print(".".join(str(int(p)) for p in v.split(".")))' "$root/ps5/sce_sys/param.json")}
dist="$root/dist/$title"
[[ -f $dist/eboot.bin ]] || { echo "make-release.sh: build first (no $dist/eboot.bin)" >&2; exit 2; }

found=$(find "$dist" \( -iname '*.dol' -o -iname '*.iso' -o -iname '*.gcm' -o -iname '*.ciso' \
    -o -iname '*.dolcard' -o -iname '*.state' -o -name settings.ini -o -name env.txt \) -print)
[[ -z $found ]] || { echo "make-release.sh: game or player files in $dist:" >&2; echo "$found" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R "$dist" "$work/$title"
mkdir -p "$work/$title/dump"
cat > "$work/$title/dump/PUT YOUR DISC HERE.txt" <<'EOF'
Put your own image of the European Eternal Darkness disc (GEDP01, .iso or
.gcm) in this folder. Any file name works.
EOF
zip_path="$root/dist/EternalDarkness-PS5-$version.zip"
rm -f "$zip_path"
(cd "$work" && COPYFILE_DISABLE=1 zip -q -r -X "$zip_path" "$title")
echo "$zip_path ($(du -h "$zip_path" | cut -f1))"
