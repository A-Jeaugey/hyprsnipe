# hyprsnipe

**A sniper scope kill mode for Hyprland.** Press a key, aim through a magnified scope, and take the shot: the window under the reticle is gone.

Think `hyprctl kill` or `xkill`, with a scope, recoil, a gunshot and a kill feed.

<!-- ![demo](docs/demo.gif) -->

## Features

- **Scope overlay** that darkens the screen around a circular lens, with a red reticle
- **Magnified lens**, adjustable with the mouse wheel (×1.5 to ×6), sharp on HiDPI screens
- **Two kinds of ammo**: headshot (instant `SIGKILL`) or tranquilizer dart (`SIGTERM`, lets the app exit gracefully)
- **Recoil, impact flash and bullet streak**, rendered in a fragment shader
- **Gunshot sound** and an **FPS-style kill feed** in the top-right corner
- **No notification daemon needed**: the kill feed is drawn by hyprsnipe itself, so it shows up the same everywhere, even in Do Not Disturb mode
- **Multi-monitor aware**: one scope per monitor, targets are picked on the monitor you aim at

## Controls

| Input | Action |
| --- | --- |
| Left click | Headshot: kill the targeted app instantly (`SIGKILL`) |
| Shift + left click | Tranquilizer: ask the targeted app to quit (`SIGTERM`) |
| Mouse wheel | Zoom in / out |
| Right click or Esc | Stand down |

The scope stands down on its own after 30 seconds without a shot.

> **Heads up:** hyprsnipe targets a window but shoots its **process**. A headshot on one Firefox window takes down every Firefox window, and anything unsaved in them. Same behaviour as `hyprctl kill`. When in doubt, use the tranquilizer.

## Requirements

- [Hyprland](https://hyprland.org)
- [Quickshell](https://quickshell.org) 0.3 or newer
- Qt 6 with the multimedia module (`qt6-multimedia` on Arch)
- `grim`, `jq`, and `flock` (from `util-linux`)

To rebuild the shaders you also need `qsb`, from `qt6-shadertools`. Prebuilt `.qsb` files are included, so this is optional.

## Installation

```sh
git clone https://github.com/A-Jeaugey/hyprsnipe.git ~/.local/share/hyprsnipe
```

Then bind the launcher to a key.

Classic `hyprland.conf`:

```ini
bind = SUPER SHIFT, X, exec, ~/.local/share/hyprsnipe/hyprsnipe
```

Lua config:

```lua
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/share/hyprsnipe/hyprsnipe"))
```

## How it works

1. The launcher snapshots every monitor with `grim` (raw PPM, so it takes milliseconds instead of a second of PNG compression) and records the cursor position.
2. Quickshell opens a full-screen overlay on each monitor. A fragment shader draws the lens from the snapshot, magnified around the aim point, and darkens everything else.
3. Window geometry is fetched once from Hyprland IPC. Nothing can move while the scope holds the input, so one snapshot is enough.
4. On click, the window under the reticle is picked with a stacking heuristic (fullscreen, then floating, then tiled, most recently focused first), and its process receives `SIGKILL` or `SIGTERM`.
5. The overlay gives the input back and a click-through kill feed slides in, then everything exits.

## Limitations

- **Hyprland only**: target picking relies on Hyprland IPC.
- **Stacking is a heuristic**: with several overlapping floating windows, the pick can occasionally be wrong. Hyprland does not expose an exact stacking order over IPC.
- **Special workspaces** (scratchpads) are not considered as targets yet.
- **The lens shows a still image**: a video playing behind the scope freezes inside the lens.
- **Multi-monitor** support is implemented but has only been tested on a single screen so far. Feedback welcome.

## Rebuilding the shaders

```sh
/usr/lib/qt6/bin/qsb --qt6 -o shaders/scope.frag.qsb shaders/scope.frag
```

## Credits

- Gunshot sound: *Sniper Rifle Firing Shot 1* by freesound_community, via [Pixabay](https://pixabay.com/sound-effects/sniper-rifle-firing-shot-1-39789/), under the [Pixabay Content License](https://pixabay.com/service/license-summary/).
- Tranquilizer sound: *Silenced Sniper Rifle* by freesound_community, via [Pixabay](https://pixabay.com/fr/sound-effects/films-et-effets-sp%C3%A9ciaux-silenced-sniper-rifle-105895/), under the same license.

These sounds are not covered by the MIT license.

## License

MIT, see [LICENSE](LICENSE).
