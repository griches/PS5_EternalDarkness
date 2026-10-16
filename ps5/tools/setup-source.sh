#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - the sources the build needs, with the console's changes.
#
#   ps5/tools/setup-source.sh    check out, patch and generate everything; safe before every build
#
# The game is Eternal Darkness Recomp (vendor/edrecomp, a submodule): its host
# layer and build. What the console needs changed in it is
# ps5/patches/edrecomp.patch, every hunk behind __PROSPERO__. The recomp's own
# tools/setup-deps.sh names the two projects it builds on; they are fetched
# here, into .deps/, at the same pins and with the recomp's patches, then the
# console's:
#
#   .deps/DolRecomp   the recompiler (built for this machine, to translate the disc)
#   .deps/GXRuntime   the runtime, Aurora and the gxcore renderer, then
#                     ps5/patches/gxruntime.patch
#
# and the game code is translated from the player's disc into gamedata/<id>/
# (the recomp's tools/generate.py): PS5_ED_DISC, else the one .iso in dump/.
# Neither the disc nor the code made from it is ever committed.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
recomp="$root/vendor/edrecomp"
deps="$root/.deps"

[[ -f $recomp/CMakeLists.txt ]] || git -C "$root" submodule update --init vendor/edrecomp >&2

# apply_once DIR PATCH: apply PATCH to the checkout DIR unless it is in already
apply_once() {
    local dir=$1 patch=$2
    [[ -s $patch ]] || return 0
    git -C "$dir" apply --reverse --check "$patch" 2>/dev/null && return 0
    git -C "$dir" apply --check "$patch" || {
        echo "setup-source.sh: ${patch##*/} does not apply to $dir" >&2
        exit 2
    }
    git -C "$dir" apply --whitespace=nowarn "$patch"
    echo "setup-source.sh: applied ${patch##*/}" >&2
}
apply_once "$recomp" "$root/ps5/patches/edrecomp.patch"

# pin NAME URL: the revision the recomp's setup-deps.sh pins NAME at, checked out
# fresh in .deps/NAME with the recomp's patch and then the console's
pin() {
    local name=$1 url=$2 dir="$deps/$1" revision stamp lower
    lower=$(tr '[:upper:]' '[:lower:]' <<<"$name")
    revision=$(sed -n "s/^pin $name [^ ]* \([0-9a-f]\{7,40\}\)\$/\1/p" "$recomp/tools/setup-deps.sh")
    [[ -n $revision ]] || { echo "setup-source.sh: no pin for $name in tools/setup-deps.sh" >&2; exit 2; }
    local patches=("$recomp/patches/$lower/eternal-darkness.patch")
    [[ -f $root/ps5/patches/$lower.patch ]] && patches+=("$root/ps5/patches/$lower.patch")
    stamp="$revision $(cat "${patches[@]}" | sha256sum | cut -d' ' -f1)"
    if [[ ! -f $dir/.ps5-stamp || $(<"$dir/.ps5-stamp") != "$stamp" ]]; then
        {
            [[ -d $dir/.git ]] || git clone -q "$url" "$dir"
            git -C "$dir" cat-file -e "$revision^{commit}" 2>/dev/null || git -C "$dir" fetch -q origin
            git -C "$dir" checkout -q -f "$revision"
            git -C "$dir" clean -q -fd -e build
            for each in "${patches[@]}"; do
                git -C "$dir" apply --whitespace=nowarn "$each" || {
                    echo "setup-source.sh: ${each##*/} does not apply to $name $revision" >&2
                    exit 2
                }
            done
        } >&2
        echo "$stamp" > "$dir/.ps5-stamp"
    fi
}
pin DolRecomp https://github.com/ExpansionPak/DolRecomp.git
pin GXRuntime https://github.com/aharonahdoot/GXRuntime.git

# The recompiler, for this machine (not the console)
dolrecomp="$deps/DolRecomp/build/dolrecomp"
if [[ ! -x $dolrecomp || $(<"$deps/DolRecomp/.ps5-stamp") != "$(cat "$deps/DolRecomp/build/.ps5-stamp" 2>/dev/null)" ]]; then
    (env -u CC -u CXX cmake -S "$deps/DolRecomp" -B "$deps/DolRecomp/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        && ninja -C "$deps/DolRecomp/build" dolrecomp) >&2
    cp "$deps/DolRecomp/.ps5-stamp" "$deps/DolRecomp/build/.ps5-stamp"
fi

# The game code, from the player's disc
disc=${PS5_ED_DISC:-}
if [[ -z $disc ]]; then
    discs=("$root"/dump/*.iso)
    [[ ${#discs[@]} -eq 1 && -f ${discs[0]} ]] || {
        echo "setup-source.sh: put your Eternal Darkness disc image (GEDP01 or GEDE01 .iso) in dump/, or set PS5_ED_DISC" >&2
        exit 2
    }
    disc=${discs[0]}
fi
game_id=$(head -c 6 "$disc")
case $game_id in GEDP01 | GEDE01) ;; *) echo "setup-source.sh: $disc is $game_id, not Eternal Darkness" >&2; exit 2 ;; esac
out="$root/gamedata/$game_id"
# What makes the code: the recompiler (pin + patch), the recomp's generator
# (tools/, config/) and the disc; not the recomp's host, which the build compiles
stamp="$(<"$deps/DolRecomp/.ps5-stamp") $(cat "$recomp"/tools/*.py "$recomp"/config/*/* | sha256sum | cut -d' ' -f1) $(stat -L -c '%s %Y' "$disc")"
if [[ ! -f $out/.ps5-stamp || $(<"$out/.ps5-stamp") != "$stamp" ]]; then
    # generate.py works from its own tree (tools/, config/, .deps/DolRecomp):
    # a scratch tree with those, so the submodule stays as it is
    gen="$deps/edgen"
    rm -rf "$gen" && mkdir -p "$gen/.deps"
    cp -R "$recomp/tools" "$recomp/config" "$gen/"
    ln -s "$deps/DolRecomp" "$gen/.deps/DolRecomp"
    mkdir -p "$root/gamedata"
    python3 "$gen/tools/generate.py" "$disc" --out "$out" >&2
    echo "$stamp" > "$out/.ps5-stamp"
fi
echo "$out"
