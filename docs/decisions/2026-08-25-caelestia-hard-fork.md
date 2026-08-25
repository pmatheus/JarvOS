# Decision: hard-fork the Caelestia C++ plugin at 2.3.0

**Date:** 2026-08-25
**Status:** decided, not yet scoped — needs its own spec and plan
**Decided by:** chairman

## Decision

Vendor upstream's C++ Qt plugin into JarvOS at **v2.3.0**, rename its QML
namespace `Caelestia.*` → `Jarvos.*`, ship it as our own package, and stop
tracking `caelestia-dots/shell` entirely. Harvest everything they built, then
cut.

Sequenced **after** the maintenance layer (Parts A and B). That ordering is
deliberate: migrations and `jarvos-update` are exactly the machinery needed to
move existing machines onto a renamed plugin without breaking them. The fork
ships as a migration on top of working infrastructure, not before it exists.

## What we are actually coupled to

Not their QML — we already forked that. The tie is a **compiled C++ Qt
plugin** we never vendored and depend on at runtime:

- 42 `import Caelestia*` sites across our QML tree
- 5 modules consumed: `Caelestia` (25 sites), `.Models` (6), `.Internal` (6),
  `.Services` (4), `.Images` (1)
- 32 C++ types: `AppDb`, `AppEntry`, `CUtils`, `ImageAnalyser`, `Qalculator`,
  `Requests`, `Toast`, `Toaster`, `CircularBuffer`,
  `CircularIndicatorManager`, `HyprDevices`, `HyprExtras`, `HyprKeyboard`,
  `LinearIndicatorManager`, `LinearIndicatorSegment`, `LogindManager`,
  `SparklineItem`, `VisualiserBars`, `FileSystemEntry`, `FileSystemModel`,
  `BeatTracker`, `CavaProvider`, `Cpu`, `DiskInfo`, `Gpu`, `lyricCandidate`,
  `Lyrics`, `LyricsBackend`, `Memory`, `ServiceRef`, `Storage`, `UsageFmt`,
  `IUtils`
- Installed as 16 `.so` files under `/usr/lib/qt6/qml/Caelestia/`

Upstream source is a release tarball carrying the full `plugin/` tree and
CMake: **126 C++ files, 16,442 lines**, GPL-3.0. Obtainable from
`https://github.com/caelestia-dots/shell` releases; a copy was already in
`~/.cache/yay/caelestia-shell/`.

## Why now

Upstream breaks us on their schedule, repeatedly:

- 2.0.2 dropped `Caelestia.Internal/ArcGauge` and took the shell down; fixed
  with a local drop-in.
- 2.3.0 **deletes `LogindManager`**, which `modules/IdleMonitors.qml` uses.
  Replaced by `SessionManager` in a different module.
- 2.3.0 absorbs the entire config system into C++ (`Config`, `*Config`,
  `*Tokens` types), which collides with our forked `config/Config.qml`.

We are one `pacman -Syu` away from the same outage each time.

## Why 2.3.0 rather than 2.0.3 (what we run)

Forking at 2.0.3 would have been free — every type we use is present and our
QML already works against it. We took 2.3.0 anyway to harvest their remaining
work in one final pull, notably the SDF `Caelestia.Blobs`, which is the known
fix for the drawer ghost-blob rendering bug we still carry.

The cost is real and must be planned for: porting our QML from the 2.0.x
plugin API to 2.3.0 is a genuine porting job, not a namespace rename.
Specifically `IdleMonitors.qml` must move to `SessionManager`, and our
`Config.qml` has to be reconciled against 2.3.0's C++ config types.

## What the fork also buys

- Drops the `caelestia-cli` and `caelestia-shell` package dependencies.
- Removes the `qs -c caelestia` naming contortion and the
  `~/.config/quickshell/caelestia → jarvos` symlink that exists only because
  `caelestia-cli` is hardwired to that config name.
- Lets the `caelestia:` IPC keybind namespace become `jarvos:`.

## Licensing — unchanged

The plugin is GPL-3.0 and so is JarvOS. Forking harder does not alter this;
a derivative work carries the licence regardless of how much is modified.
See `2026-08-25-maintenance-layer-part-b-update.md` Task 12 and
[jarvos-license-gpl3] in memory.

## Not yet decided

- Whether the renamed plugin ships as a second package or is folded into
  `jarvos`.
- How the migration moves existing machines across the rename.
- Whether to take 2.3.0's C++ config system or keep our QML `Config.qml`.
