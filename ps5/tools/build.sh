#!/usr/bin/env bash
# Eternal Darkness for the PlayStation 5 - build the game into dist/<TITLE_ID>/.
#
#   ps5/tools/build.sh [ninja arguments]
#
# Fetches, patches and generates the sources (tools/setup-source.sh: the game
# code comes from the player's disc in dump/), then configures the recomp's own
# build (vendor/edrecomp) with the payload SDK's CMake toolchain (once) and
# ps5/cmake/ps5-game.cmake, which gives it Dawn and SDL3 for the console and
# the title's link (tools/link-title.sh).
#
#   PS5_BUILD_DIR    the build tree (default build/game; the Linux VM's own disk
#                    is several times faster than the shared folder)
#   PS5_VULKAN_DIR   the PS5_Vulkan checkout (default ../PS5_Vulkan)
#   PS5_ED_DISC      the disc image (default: the one .iso in dump/)
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
generated=$(bash "$ps5/tools/setup-source.sh")
dawn=$(bash "$ps5/tools/setup-dawn.sh")
sdl=$(bash "$ps5/tools/setup-sdl.sh")
sdk=$(bash "$ps5/tools/setup-sdk.sh")
# The title's own RADV (120 Hz on a VRR TV); link-title.sh links RADV_ARCHIVE.
export RADV_ARCHIVE=${RADV_ARCHIVE:-$(PS5_VULKAN_DIR="$vulkan" bash "$ps5/tools/setup-radv.sh")}
build=${PS5_BUILD_DIR:-$root/build/game}
ninja=$(command -v ninja || echo "$HOME/.local/bin/ninja")
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}

# A different disc (or a regenerate) is a different set of chunk files: CMake globs them
if [[ -f $build/build.ninja && $(<"$generated/.ps5-stamp") != "$(cat "$build/.ps5-generated" 2>/dev/null)" ]]; then
    rm -f "$build/CMakeCache.txt" "$build/build.ninja"
fi
if [[ ! -f $build/build.ninja ]]; then
    mkdir -p "$build"
    cmake -S "$root/vendor/edrecomp" -B "$build" -G Ninja -DCMAKE_MAKE_PROGRAM="$ninja" \
        -DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" \
        -DCMAKE_PROJECT_EternalDarkness_INCLUDE="$ps5/cmake/ps5-game.cmake" \
        -DPS5_PORT_DIR="$root" -DPS5_VULKAN_DIR="$vulkan" -DDAWN_DIR="$dawn" -DSDL_DIR="$sdl" \
        -DED_GXRUNTIME_DIR="$root/.deps/GXRuntime" -DED_GENERATED_DIR="$generated" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=OFF > "$build/configure.log" 2>&1 \
        || { tail -60 "$build/configure.log" >&2; exit 1; }
    cp "$generated/.ps5-stamp" "$build/.ps5-generated"
fi
"$ninja" -C "$build" "${@:-EternalDarkness}"
