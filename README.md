# Eternal Darkness for the PlayStation 5

**Eternal Darkness: Sanity's Requiem** (GameCube, 2002) as PS5 homebrew, title
`PPSA99314`, at 4K and 60 frames a second, built from
[Eternal Darkness Recomp](https://github.com/griches/EternalDarknessRecomp) and
**your own disc**. Version 0.8.0.

> **European disc only.** You need your own image of the **European GameCube disc,
> `GEDP01`**. The USA disc (`GEDE01`) is not supported.

## What you need

- A PS5 that runs homebrew (etaHEN or similar), with ShadowMountPlus and an FTP
  server (port 2121).
- Your own image of the European disc: an `.iso` or `.gcm` (not a compressed
  RVZ or CISO).

## Install

1. Download `EternalDarkness-PS5-....zip` from the release and unzip it: a
   `PPSA99314` folder.
2. Copy that folder to the console as `/data/homebrew/PPSA99314/` over FTP.
3. Put your disc image in `/data/homebrew/PPSA99314/dump/` (any name).
4. Wait for **Eternal Darkness** to appear on the home screen and start it. If it
   does not appear, restart ShadowMountPlus. The first start reads the game's
   program from your disc (a second or two), then the launcher offers the disc.

The game's files (its program, graphics, sound and music) come from your disc.

Saves and settings stay in `/data/homebrew/PPSA99314/` (`saves/`, `settings.ini`,
and the memory cards `ed-GEDP01-slot-a.dolcard` and `...-slot-b.dolcard`).
Copying a new build over the folder leaves them, the disc and the texture pack
alone.

## HD texture pack

1. Get a Dolphin HD texture pack for Eternal Darkness: a folder of `tex1_....png`
   or `tex1_....dds` files. A DDS pack (BC7) stays compressed in the console's
   graphics memory, a quarter of a PNG pack's.
2. Copy those files (any subfolders are fine) to
   `/data/homebrew/PPSA99314/textures/`. A full pack is several GB, so the copy
   takes a while.
3. Start the title again: it finds the pack when it starts. **Options > Game >
   HD textures** turns it on and off while you play.

Packs can sit side by side in `textures/`; where two have the same texture, a
folder with *supplement* or *override* in its name wins (such as the PAL
supplement: the European disc's screens and words the main pack misses).

## What is better than on the GameCube

- **4K at 60 frames a second**, with full colour (no 6-bit banding). Options can
  also draw at 720p, 1080p or 1440p.
- **Widescreen**: the game's own 16:9 mode (more of the room at the sides, not
  stretched) with the HUD and prompts at the screen's edges; 4:3 too.
- **New baked shadows** (below): the rooms' light and shadow redrawn sharp.
- **Crisp game text**: the game's lettering redrawn in two styles, *Sharp* or
  *Tome* (old typefaces), or *Original* as on the disc.
- **HD texture packs** in Dolphin's format.
- **Modern controls** and remapping, with PlayStation button prompts, the game's
  own prompts included.
- **Save anywhere**: the pause menu has four save slots that hold the whole
  moment, besides the game's own memory-card saves (slots A and B).
- **A launcher**: Continue, New game or any save slot straight from the start.
- **Problem reports**: if the game stops responding, stops or crashes, it says
  so on screen and writes a report to `saves/reports/` (fetch it over FTP and
  send it with a few words on what you were doing).
- **Shaders ready**: the title ships the shader caches a console made, so a fresh
  install starts without compiling them.

## Controls

| Action | Modern (default) | Original (GameCube positions) |
| --- | --- | --- |
| Move | Left stick | Left stick |
| Attack / Confirm | R2 or Cross | Cross |
| Action / Cancel | Circle | Circle |
| Target / Aim | L2 or R1 | R2 |
| Sprint | L3 (toggle), or hold L1 | L2 |
| Creep | R3 (toggle) | Square |
| Reload | Square | R1 |
| Quickcast | Triangle | Triangle |
| Spells | D-pad | D-pad |
| Game's pause menu | Options | Options |
| This port's menu (saves, options) | Create | Create |

In the game's own menus L1 and R1 page left and right. **Options > Controls**
switches layout, makes Sprint, Creep and Target hold or toggle, sets the stick
deadzone and vibration, and **Button mapping** rebinds any action (that layout is
*Custom*).

## The new baked shadows

Eternal Darkness lights its rooms with pre-drawn light maps: the window light on
the floors, the shadows under the furniture, the glow of the lamps. On the disc
they are small and compressed, so at 4K their edges break up into blocks and
smears. With **Options > Game > Baked shadows: Sharp** (the default) each room's
light maps are rebuilt four times larger as the room loads, with the compression
blocks evened out and edges doubled along their own direction, so light and
shadow keep clean edges. **Original** shows them as on the disc.

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
- `ps5/shader-cache` holds the shader caches a console filled (Dawn's
  `dawn_cache.db` and the driver's `radv-shader-cache`). `link-title.sh` puts them
  in `res/shader-cache` and `startup.c` copies them into place on a start that has
  none. Take them from a console again after a change to Dawn, Mesa or the
  shaders.

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

On the console the title folder also needs the disc, `dump/<id>.iso` under
`/data/homebrew/PPSA99314/`; the title reads `generated/main.dol` out of it on
its first start (`ps5/tools/console.sh game-files` copies both instead).
`ps5/tools/package-release.sh VERSION` zips `dist/PPSA99314/` for a release, with an empty
`dump/` for the disc.
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
The title carries every component's licence text in `licenses/` (the recomp's
`THIRD_PARTY.md` lists them, and SDL, Dawn, Mesa and PS5_Vulkan are added).
