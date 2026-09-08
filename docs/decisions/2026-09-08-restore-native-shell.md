# Restore JarvOS and remove Caelestia runtime dependencies

The user rejected the Omarchy shell replacement and asked to restore the
original JarvOS shell while continuing its native implementation. Commit
30e8d3a reverts the Omarchy migration. The original QML layout and saved
palette remain in use.

D1. JarvOS owns shell startup, IPC, scheme selection, wallpaper application
and recording through `bin/jarvos-shell` and `bin/jarvos-desktop`.
`lib/desktop.py` contains the native backend. It uses the existing JarvOS
Material palette generator and independent Arch packages. Neither
`caelestia-cli` nor `caelestia-shell` is required or installed.

D2. Keep legacy preference directories and shortcut namespaces compatible.
A path named `caelestia` is not a package dependency. Startup translates
saved launcher commands to the native executable and saves the original
configuration as `shell.pre-jarvos-desktop.json`. Palette tables retain
upstream attribution. Current colours are preserved during startup.

D3. Keep the original bar, launcher, settings, notifications and shortcuts.
The inactive Omarchy checkout and configuration were moved into the local
rollback archive. Adopting utilities does not authorize replacing the user's
visual design.

## Validation

V1. The full project gate passed, including 167 QML tests. Native backend
pytest tests and hypr-box IPC tests passed. Ruff, ty and shellcheck passed.

V2. The restored bar was inspected on screen. The launcher opened a new
Kitty window, which was then closed by its exact address. Settings opened
through native IPC. Hyprland reported no configuration errors.

V3. A real recording was started, paused, resumed and stopped. ffprobe
reported H.264 at 1920×1080 and Opus audio in a valid MP4. Recording control
checks both PID and process start time and uses pidfds to signal only its
own recorder. Mutation commands serialize with a file lock.

V4. Wallpaper preview left live state unchanged. An isolated-state test
applied the already displayed image through the real awww daemon, verified
wallpaper persistence, preserved a static palette and generated light mode.
The saved live palette remained byte-identical. A hidden QML probe observed
60 visualizer frames with 45 bars and release of its final consumer.

## Limits

R1. A fresh external review was attempted with read-only tools, but the
reviewer reached its session quota before returning a review. Local checks
and live validation are the available evidence.

R2. Existing optional Spotlight indexing and some settings icons emitted
warnings when those panels opened. No file index was created as part of
this dependency change. The idle shell starts without QML errors.

R3. Dynamic palettes use the selected Material variant. The legacy
`--no-smart` and `--notify` flags are accepted for call compatibility.
There is no Caelestia smart-variant selection or external theme-hook runner.

V5. The launcher initially showed zero rows even though the native scheme
query returned a match. A delayed PropertyAction froze the model update.
Removing that action preserves the state bindings and renders the loaded
results. `tests/desktop/check-live-launcher.sh` reproduces the real QML path
without opening a window and requires one JarvOS result with no warnings.
