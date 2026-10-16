# Eternal Darkness for the PlayStation 5

A PS5 homebrew build of [Eternal Darkness Recomp](https://github.com/griches/EternalDarknessRecomp),
the static recompilation of **Eternal Darkness: Sanity's Requiem** (GameCube), as
title `PPSA99314`. The game code is translated from **your own disc**; nothing of
the game is in this repository, and a built title holds code made from the disc,
so it stays with whoever built it.

## How it works

- `vendor/edrecomp` is the recomp (a submodule): its host layer, launcher and
  build. What the console needs changed in it is `ps5/patches/edrecomp.patch`,
  every hunk behind `__PROSPERO__`.
- `ps5/tools/setup-source.sh` fetches the two projects the recomp builds on at
  its pins (DolRecomp, GXRuntime) with its patches and then the console's
  (`ps5/patches/gxruntime.patch`), builds the recompiler for the build machine,
  and translates `main.dol` from the disc in `dump/` into `gamedata/<id>/`.
- Graphics are GXRuntime's gxcore renderer on Aurora and Dawn (WebGPU), Dawn's
  Vulkan backend running on the RADV driver linked into the title
  ([PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan)). `ps5/patches/dawn.patch`
  adds the console to Dawn: the driver linked in, and the output as a
  VK_KHR_display surface. SDL3 gets the console's video, audio and pad drivers
  (`ps5/sdl`, `ps5/patches/sdl.patch`).
- `ps5/src/startup.c` runs before the game: klog, the title folder as the
  working folder (the recomp finds `generated/main.dol`, `dump/<id>.iso`,
  `res/`, `saves/` and `settings.ini` there) and the caches in `cache/`.

## Build

From macOS, through the Lima VM `ps5` that holds the PS5 stack (PS5_Vulkan,
PS5_Mesa, PS5_PayloadSDK, LLVM 22):

```sh
git submodule update --init
cp /path/to/GEDP01.iso dump/            # or GEDE01: your own disc
ps5/tools/vm.sh build                   # -> dist/PPSA99314/
ps5/tools/vm.sh deploy                  # FTP to the console (PS5_HOST)
ps5/tools/vm.sh run                     # launch and follow klog
```

On the console the title folder also needs the disc and the translated
`main.dol`: `dump/<id>.iso` and `generated/main.dol` under
`/data/homebrew/PPSA99314/`.

The home-screen art (`ps5/art`, converted by `ps5/art/make-title-art.sh`) is
the port's own, made with ChatGPT in the look of the game's cover; nothing in it
is from the game.

## Licence

GPL-3.0-or-later, as Eternal Darkness Recomp and GXRuntime. The PS5 layer
(`ps5/src`, `ps5/sdl`, `ps5/tools`) comes from the author's other PS5 ports.
