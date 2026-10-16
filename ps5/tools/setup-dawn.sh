#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - Dawn at the revision Aurora pins, patched for the console.
#
#   ps5/tools/setup-dawn.sh      fetch it into .deps/dawn (once a revision), print the path
#
# GXRuntime's Aurora (.deps/GXRuntime/graphics/aurora, tools/setup-source.sh)
# names its Dawn in its CMakeLists.txt (AURORA_DAWN_REF, a commit of
# encounter/dawn). This fetches that commit and Dawn's own third-party sources
# (tools/fetch_dawn_dependencies.py), then applies ps5/patches/dawn.patch: the
# PS5 as a platform, the RADV linked into the title in place of a Vulkan
# library, and the console's surface (VK_KHR_display). Dawn's Abseil gets
# ps5/patches/dawn-abseil.patch (its raw log writes with write(), not syscall()).
#
# SPDX-License-Identifier: MIT
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
dawn="$root/.deps/dawn"
versions="$root/.deps/GXRuntime/graphics/aurora/CMakeLists.txt"
[[ -f $versions ]] || bash "$root/ps5/tools/setup-source.sh" > /dev/null
revision=$(sed -n 's/^_aurora_dependency_version(AURORA_DAWN_REF "\([0-9a-f]\{40\}\)".*/\1/p' "$versions")
[[ -n $revision ]] || { echo "setup-dawn.sh: no AURORA_DAWN_REF in $versions" >&2; exit 2; }
patch="$root/ps5/patches/dawn.patch"
abseil_patch="$root/ps5/patches/dawn-abseil.patch"
stamp="$revision $(cat "$patch" "$abseil_patch" | sha256sum | cut -d' ' -f1)"

if [[ ! -f $dawn/.ps5-dawn || $(<"$dawn/.ps5-dawn") != "$stamp" ]]; then
    {
        if [[ ! -d $dawn/.git ]]; then
            mkdir -p "$dawn"
            git -C "$dawn" init -q
            git -C "$dawn" remote add origin https://github.com/encounter/dawn.git
        fi
        if [[ $(git -C "$dawn" rev-parse -q --verify HEAD 2>/dev/null) != "$revision" ]]; then
            git -C "$dawn" fetch -q --depth 1 origin "$revision"
            git -C "$dawn" checkout -q -f FETCH_HEAD
            (cd "$dawn" && python3 tools/fetch_dawn_dependencies.py)
        fi
        git -C "$dawn" checkout -q -f HEAD -- .
        git -C "$dawn" apply --whitespace=nowarn "$patch"
        git -C "$dawn/third_party/abseil-cpp" checkout -q -f HEAD -- .
        git -C "$dawn/third_party/abseil-cpp" apply --whitespace=nowarn "$abseil_patch"
    } >&2
    echo "$stamp" > "$dawn/.ps5-dawn"
fi
echo "$dawn"
