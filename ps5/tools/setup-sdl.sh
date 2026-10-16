#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - SDL3 at the release Aurora pins, patched for the console.
#
#   ps5/tools/setup-sdl.sh       fetch it into .deps/SDL (once a release), print the path
#
# GXRuntime's Aurora names its SDL3 in its CMakeLists.txt (AURORA_SDL3_REF,
# a release tag). ps5/patches/sdl.patch registers the console's video, audio and
# joystick drivers, which live in ps5/sdl/, and builds them when the toolchain
# says PS5.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
sdl="$root/.deps/SDL"
versions="$root/.deps/GXRuntime/graphics/aurora/CMakeLists.txt"
[[ -f $versions ]] || bash "$root/ps5/tools/setup-source.sh" > /dev/null
tag=$(sed -n 's/^_aurora_dependency_version(AURORA_SDL3_REF "refs\/tags\/\([^"]*\)".*/\1/p' "$versions")
[[ -n $tag ]] || { echo "setup-sdl.sh: no AURORA_SDL3_REF in $versions" >&2; exit 2; }
patch="$root/ps5/patches/sdl.patch"
stamp="$tag $(sha256sum "$patch" | cut -d' ' -f1)"

if [[ ! -f $sdl/.ps5-sdl || $(<"$sdl/.ps5-sdl") != "$stamp" ]]; then
    {
        if [[ ! -d $sdl/.git ]]; then
            git clone -q --depth 1 -b "$tag" https://github.com/libsdl-org/SDL.git "$sdl"
        elif [[ $(git -C "$sdl" describe --tags --exact-match 2>/dev/null) != "$tag" ]]; then
            git -C "$sdl" fetch -q --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
            git -C "$sdl" checkout -q -f "$tag"
        fi
        git -C "$sdl" checkout -q -f HEAD -- .
        git -C "$sdl" apply --whitespace=nowarn "$patch"
    } >&2
    echo "$stamp" > "$sdl/.ps5-sdl"
fi
echo "$sdl"
