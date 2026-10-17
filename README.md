# Eternal Darkness for the PlayStation 5

**Eternal Darkness: Sanity's Requiem** (GameCube) as PS5 homebrew, title `PPSA99314`,
built from [Eternal Darkness Recomp](https://github.com/griches/EternalDarknessRecomp)
and **your own disc**.

## Quick start

**You need**
- A PS5 that runs homebrew (etaHEN or similar), with ShadowMountPlus and an FTP
  server (port 2121).
- Your own disc image of the **European disc**, `GEDP01`. The USA disc is not supported.
- The title built from it (see [Build](#build)), which gives `dist/PPSA99314/`. The
  title holds code translated from your disc, so there is no download.

**Install**
1. Copy `dist/PPSA99314/` to the console as `/data/homebrew/PPSA99314/`
   (`ps5/tools/console.sh deploy` does it over FTP). Include `sce_sys/icon0.png`
   in the first upload: ShadowMountPlus will not register a title without it.
2. Copy your disc image to `/data/homebrew/PPSA99314/dump/GEDP01.iso`, and the build's `gamedata/<id>/main.dol` to
   `/data/homebrew/PPSA99314/generated/main.dol` (`ps5/tools/console.sh game-files`
   does both).
3. Wait for **Eternal Darkness** to appear on the home screen and start it. If it
   does not appear, restart ShadowMountPlus.

**HD textures**
1. Get a Dolphin HD texture pack for Eternal Darkness (a folder of `tex1_....png` files).
2. Copy those files (any subfolders are fine) to `/data/homebrew/PPSA99314/textures/`.
   A full pack is several GB, so the copy takes a while.
3. Start the title again. Options > HD textures turns the pack on and off.

**Playing**
- The DualSense's **Create** button opens the pause menu: four save slots, Options, Quit.
- Saves and settings stay in `/data/homebrew/PPSA99314/`: `saves/`, `settings.ini`
  and `ed-GEDP01-slot-a.dolcard` (the game's memory card; `...-slot-b.dolcard` is slot B).
  Copying a new build over the folder leaves them alone.
- If the game stops responding, stops or crashes, it writes a report to
  `/data/homebrew/PPSA99314/saves/reports/` (for a hang, with a `.state` of that
  moment). Fetch those files over FTP and send them with a few words on what you
  were doing.

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
cp /path/to/GEDP01.iso dump/            # your own European disc
ps5/tools/vm.sh build                   # -> dist/PPSA99314/
ps5/tools/vm.sh deploy                  # FTP to the console (PS5_HOST)
ps5/tools/vm.sh run                     # launch and follow klog
```

On the console the title folder also needs the disc and the translated
`main.dol`: `dump/<id>.iso` and `generated/main.dol` under
`/data/homebrew/PPSA99314/` (`ps5/tools/console.sh game-files`).
`ps5/tools/console.sh` also deploys and runs from macOS itself, for when the VM
cannot reach the console, and writes the title's `env.txt`: `KEY=VALUE` lines
the recomp reads as its environment (for example `ED_QUICKLOAD=saves/slot1.state`
to start in a save, `AURORA_GPU_TIME_LOG=1` for frame times in klog).

The home-screen art (`ps5/art`, converted by `ps5/art/make-title-art.sh`) is
the port's own, made with ChatGPT in the look of the game's cover; nothing in it
is from the game. The music that plays while the tile is highlighted is: the
first 30 seconds of one of the game's insanity themes, in
`ps5/sce_sys/snd0.at9`. `ps5/art/make-title-music.sh` remakes it from a disc
(needs FFmpeg and [ps5-at9-converter](https://github.com/blackbearreloaded/ps5-at9-converter)
beside this repo).

## Licence

GPL-3.0-or-later, as Eternal Darkness Recomp and GXRuntime. The PS5 layer
(`ps5/src`, `ps5/sdl`, `ps5/tools`) comes from the author's other PS5 ports.
