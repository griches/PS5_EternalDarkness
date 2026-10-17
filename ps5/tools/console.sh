#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - deploy and run from macOS itself.
#
#   ps5/tools/console.sh deploy              dist/<TITLE_ID>/ to the console (FTP)
#   ps5/tools/console.sh game-files          the disc image and main.dol into the title folder
#   ps5/tools/console.sh run [SECONDS]       launch it and follow klog (default 120 s)
#   ps5/tools/console.sh env [KEY=VALUE...]  write the title's env.txt (no arguments: remove it)
#   ps5/tools/console.sh quit                close the title
#
# vm.sh deploy and vm.sh run do the same from the Linux VM; this is for when the
# VM cannot reach the console (macOS's local network permission). It uses the
# Mac's PS5_Vulkan checkout (../PS5_Vulkan, PS5_HOST in its .env) and needs the
# console's ftpsrv (2121), klogsrv (3232) and PS5_Vulkan's ps5vkctl (9111).
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$ps5/sce_sys/param.json")
host=${PS5_HOST:-$(sed -n 's/^PS5_HOST=//p' "$vulkan/.env")}
ftp="ftp://$host:2121/data/homebrew/$title_id"

case ${1:?usage: console.sh deploy|game-files|run|env|quit} in
deploy)
    # The art and tile music always go: the tool skips a file whose size matches
    # the console's copy, and every 3840x2160 pic0/pic1.dds has the same size, as
    # does every 30 s snd0.at9. The home screen shows the copy in
    # /user/appmeta/<TITLE_ID>, taken when the title was registered, so that one
    # is refreshed too.
    art=(sce_sys/icon0.png sce_sys/pic0.dds sce_sys/pic1.dds sce_sys/snd0.at9)
    always=(--always eboot.bin)
    for file in "${art[@]}"; do always+=(--always "$file"); done
    # res/ (12 MB) always goes in full too: its images change without changing
    # size (the menus' key icons, af1d7b8)
    while IFS= read -r file; do always+=(--always "${file#"$root/dist/$title_id/"}"); done \
        < <(find "$root/dist/$title_id/res" -type f)
    python3 "$vulkan/tools/deploy-title-folder.py" "${always[@]}" "$root/dist/$title_id"
    for file in "${art[@]}"; do
        curl -s -T "$root/dist/$title_id/$file" "ftp://$host:2121/user/appmeta/$title_id/${file#sce_sys/}" ||
            echo "home-screen art not refreshed: /user/appmeta/$title_id/${file#sce_sys/}" >&2
    done
    ;;
game-files)
    for game in "$root"/gamedata/*/; do
        id=$(basename "$game")
        disc=$(readlink -f "$root/dump/$id.iso" 2>/dev/null || echo "$root/dump/$id.iso")
        curl -s --ftp-create-dirs -T "$game/main.dol" "$ftp/generated/main.dol"
        curl -s --ftp-create-dirs -T "$disc" "$ftp/dump/$id.iso"
        echo "$id: generated/main.dol and dump/$id.iso sent"
    done
    ;;
run)
    seconds=${2:-120}
    run_dir="$root/klog/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$run_dir"
    python3 "$vulkan/tools/run-title.py" "$title_id" \
        --until '\[Eternal Darkness\] ends' --timeout "$seconds" \
        --echo 'fatal|FAILED|Fatal|\[run\]|\[quick\]|\[pipelines\]|\[gpu-time\]|\[speed\]|env.txt|startup' \
        --elf "$root/build/last-title.elf" --output "$run_dir/klog.log" || true
    echo "klog: $run_dir/klog.log"
    ;;
env)
    shift
    if [[ $# -eq 0 ]]; then
        curl -s -Q "DELE /data/homebrew/$title_id/env.txt" "ftp://$host:2121/" > /dev/null || true
        echo "env.txt removed"
    else
        printf '%s\n' "$@" | curl -s -T - "$ftp/env.txt"
        printf 'env.txt: %s\n' "$@"
    fi
    ;;
quit)
    printf 'kill %s\n' "$title_id" | nc -w 5 "$host" 9111
    ;;
*)
    echo "usage: console.sh deploy|game-files|run|env|quit" >&2
    exit 2
    ;;
esac
