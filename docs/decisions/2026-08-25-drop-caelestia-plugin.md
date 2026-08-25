# Decision: drop the Caelestia C++ plugin entirely, port to Quickshell natives

**Date:** 2026-08-25
**Status:** decided, not yet scoped — needs its own spec and plan
**Decided by:** chairman
**Supersedes:** an earlier decision the same day to vendor and rename upstream's
plugin at v2.3.0. See "Why the earlier framing was wrong" below.

## Decision

Remove the dependency on `caelestia-shell` completely. Replace every
`Caelestia.*` type we use with a Quickshell native or a small amount of our
own QML. Vendor none of their C++.

Sequenced **after** the maintenance layer (Parts A and B), which supplies the
migration machinery needed to move existing machines off the
`caelestia-shell` package.

## Why this is feasible — the measured surface

Counting `import` sites (42 across 5 modules) badly overstated the coupling.
The API surface we actually use is tiny:

| Type | Refs | What we call | Replacement |
|---|---|---|---|
| `Toaster` / `Toast` | 66 | `Toaster.toast()` ×31, `.toasts` ×2 | QML singleton + `ListModel` |
| `Requests` | 8 | `.get` ×7, `.resetCookies` ×1 | `Quickshell.Io` / XMLHttpRequest |
| `CUtils` | 5 | `copyFile`, `deleteFile`, `saveItem`, `toLocalFile` | `Quickshell.Io` `Process` / `FileView` |
| `ServiceRef` | 4 | lifecycle helper | QML |
| `FileSystemModel` / `Entry` | 7 | file listing | `Quickshell.Io`, `FolderListModel` |
| `CircularBuffer` | 4 | ring buffer | plain JS array |
| `Storage` / `Memory` | 6 | `/proc` reads | `FileView` |
| `SparklineItem` | 2 | custom item | QML `Canvas` / `Shape` |
| `Qalculator` | 2 | calculator | `qalc` CLI via `Process` |
| `ImageAnalyser` | 2 | colour extraction | **`ColorQuantizer`** (native) or matugen |
| `AppDb` | 2 | desktop entries | **`DesktopEntries`** (native) |
| `HyprKeyboard` / `HyprExtras` | 2 | Hyprland IPC | **`Quickshell.Hyprland`** (native) |
| `LogindManager` | 1 | session | `UPower` / `loginctl` via `Process` |
| `IUtils` | 1 | `urlForPath` | one line of JS |
| `CircularIndicatorManager` | 1 | indicator maths | QML |
| `CavaProvider` / `BeatTracker` | 2 | visualiser FFT + beat | see below |

**11 of the 32 exported types are never used at all**: `Cpu`, `Gpu`,
`DiskInfo`, `Lyrics`, `LyricsBackend`, `UsageFmt`, `VisualiserBars`,
`HyprDevices`, `LinearIndicatorManager`, `LinearIndicatorSegment`, `AppEntry`.

Quickshell already provides natively: `DesktopEntries`, `ColorQuantizer`,
`Quickshell.Hyprland`, `Quickshell.Io` (`FileView`, `Process`, `Socket`,
`IpcHandler`, `JsonAdapter`), and `Services.{Mpris, Notifications, Pam,
Pipewire, Polkit, SystemTray, UPower, Greetd}`.

## Proof it works: the lock screen

`modules/lock/` imports **zero** Caelestia. It runs entirely on
`Quickshell.Services.Pam`, `UPower`, `Notifications`, `Quickshell.Io`,
`Wayland`, `Widgets`, plus our own `qs.*` modules — a substantial, fully
custom module already living on natives. That is the pattern for the rest.

Of the non-shell modules, only `modules/setup/Setup.qml` still imports
Caelestia.

## The two things natives do not cover

**Audio visualiser** (`services/Audio.qml`): decided — run the `cava` CLI
under `Quickshell.Io` `Process` with a raw output config and parse bar values
off stdout. Same library doing the same FFT, across a pipe instead of linked
in; `cava` is already installed. Preserves the current spectrum-bar look.
`BeatTracker` (aubio) is not covered by this and needs a separate decision if
beat-synced behaviour is to be kept.

**Drawer ghost blobs:** deferred, deliberately. Upstream's fix was the SDF
`Caelestia.Blobs`, which is C++ we are no longer taking. Treated as a separate
rendering bug to fix after the port, with a clean tree and no upstream in the
picture.

## Why the earlier framing was wrong

The first assessment sized the job by counting `import Caelestia*` statements
and the number of exported types, concluding we were bound to 16,442 lines of
C++ and should vendor it. Counting the *calls* instead showed the real surface
is one toast method, an HTTP GET, four file helpers, and a path-to-URL
conversion — most of the plugin reimplements what Quickshell already ships.

Import counts measure how many files touch a dependency. They say nothing
about how much of it is used, and are a bad proxy for the cost of replacing
it. Extract the called members before sizing a removal.

## What this buys

- Drops the `caelestia-shell` and `caelestia-cli` package dependencies.
- Ends breakage on upstream's schedule (2.0.2 deleted `ArcGauge`; 2.3.0
  deletes `LogindManager` and moves config into C++).
- Removes the `qs -c caelestia` naming contortion and the
  `~/.config/quickshell/caelestia → jarvos` symlink, which exist only because
  `caelestia-cli` is hardwired to that config name.
- Frees the `caelestia:` IPC keybind namespace to become `jarvos:`.
- No vendored C++ to maintain, and no CMake or plugin package to build.

## Licensing

Our QML remains a derivative of their GPL-3.0 QML, so JarvOS stays
GPL-3.0-only regardless. Dropping the plugin does not change this. See
`docs/superpowers/plans/2026-08-25-maintenance-layer-part-b-update.md` Task 12.

## Not yet decided

- Whether to keep beat-synced behaviour, and how, without aubio.
- Whether `modules/setup/Setup.qml` is ported or retired.
- Migration path moving existing machines off the `caelestia-shell` package.
