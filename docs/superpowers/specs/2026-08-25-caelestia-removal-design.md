# Removing the Caelestia C++ plugin

**Date:** 2026-08-25
**Status:** design approved, ready for an implementation plan
**Decision record:** `docs/decisions/2026-08-25-drop-caelestia-plugin.md`

## Sumário Executivo

JarvOS's shell depends at runtime on `caelestia-shell`, a compiled Qt plugin
supplying 32 QML types. We use 19 of them. Upstream deletes types on their own
schedule — 2.0.2 removed `ArcGauge` and took the shell down; 2.3.0 removes
`LogindManager` — so every `pacman -Syu` is a coin flip.

This replaces all 19 with Quickshell natives or our own QML. No C++ is
vendored, no plugin is built, no CMake enters the repo. The work lands
incrementally with the plugin still installed, so the desktop is never
dependent on a half-finished port.

## Goal

`config/.config/quickshell/jarvos/` contains no `import Caelestia*`, the shell
runs without `caelestia-shell` installed, and no feature is lost except where
this document says otherwise.

## Non-goals

- **Not** a rewrite of the shell. Replacements match current behaviour; visual
  or UX changes are out of scope and belong in their own work.
- **Not** the drawer ghost-blob fix. Deferred deliberately — upstream's answer
  was the SDF `Caelestia.Blobs`, C++ we are not taking. Separate bug, fixed
  after the port against a clean tree.
- **Not** the shell relocation to `/etc/xdg/quickshell/jarvos/`.
- **Not** Part B of the maintenance layer, which is paused for this.

## Architecture

### Everything becomes ordinary QML in `qs.*`

Because no replacement is C++, none of it needs a plugin namespace. Each lands
in the existing module structure the shell already uses — `pragma Singleton`,
directory-based imports, no `qmldir` (Quickshell auto-registers):

| Caelestia | Becomes |
|---|---|
| `Toaster`, `Toast` | `services/Toaster.qml`, `components/misc/Toast.qml` |
| `CUtils`, `IUtils` | `utils/Files.qml` |
| `Requests` | `utils/Http.qml` |
| `Qalculator` | `utils/Calc.qml` |
| `ImageAnalyser` | `utils/Images.qml` (exists — extend) |
| `AppDb` | `modules/launcher/services/AppDb.qml` |
| `FileSystemModel`, `FileSystemEntry` | `utils/FileSystemModel.qml` |
| `CircularBuffer` | `utils/CircularBuffer.qml` |
| `SparklineItem` | `components/misc/Sparkline.qml` |
| `CircularIndicatorManager` | folded into `components/controls/CircularIndicator.qml` |
| `HyprExtras`, `HyprKeyboard` | `services/Hypr.qml` (exists — extend) |
| `LogindManager` | `services/Session.qml` |
| `ServiceRef` | `components/misc/ServiceRef.qml` |
| `CavaProvider`, `BeatTracker` | `services/Audio.qml` (exists — extend) |

### Coexistence during the port

The plugin stays installed until nothing imports it. Replacements carry
different names from the Caelestia types, so both exist side by side and each
type migrates independently. After every type, the shell must launch and the
affected surface must work. Any step can be reverted alone.

The plugin is removed only in the final step, once
`grep -r 'import Caelestia' config/.config/quickshell/jarvos/` is empty.

## Replacement design

### Free — delete only

Three files import a Caelestia module and use nothing from it:
`modules/controlcenter/appearance/AppearancePane.qml:15`,
`modules/controlcenter/components/WallpaperGrid.qml:10`, and the plain
`import Caelestia` at `modules/utilities/cards/RecordingList.qml:9` (its
`Caelestia.Models` import on line 10 is real and stays for now).

Thirteen types are never used and need no replacement at all: `Cpu`, `Gpu`,
`Memory`, `Storage`, `DiskInfo`, `UsageFmt`, `Lyrics`, `LyricsBackend`,
`lyricCandidate`, `VisualiserBars`, `HyprDevices`, `LinearIndicatorManager`,
`LinearIndicatorSegment`. `AppEntry` is never named explicitly either; it is
the implicit element type of `AppDb.apps` and the replacement defines its own
shape.

### Trivial — direct native or a few lines

**`IUtils.urlForPath(path, fillMode)`** — one call site
(`components/images/CachingImage.qml:12`). A URL construction; becomes a JS
function in `utils/Files.qml`.

**`CUtils`** — exactly four members, five call sites: `copyFile(src, dest)`,
`deleteFile(url)`, `toLocalFile(url)`, and `saveItem(source, dest, rect?, cb)`.
The first three are `Quickshell.Io` `Process` or plain JS URL handling.
`saveItem` grabs a QML item to a file and is the only one with real substance —
Qt's `Item.grabToImage()` covers it, with the callback preserved.

**`Requests`** — `get(url, onSuccess, onError?)` and `resetCookies()`, seven
sites across `services/Weather.qml` and `services/LyricsService.qml`. QML's
`XMLHttpRequest` covers both; `resetCookies` becomes a no-op or a fresh
request context, whichever the lyrics flow actually needs.

**`Qalculator.eval(expr, showResult?)`** — two sites in one file. Shell out to
the `qalc` CLI through `Quickshell.Io` `Process`. `libqalculate` is already an
installed dependency, so this adds nothing.

**`ImageAnalyser`** — `dominantColour`, `luminance`, `requestUpdate()`,
`sourceItem`/`source`. Quickshell's native `ColorQuantizer` supplies dominant
colour; luminance is arithmetic on the result.

### Moderate — real components, small surfaces

**Toast system** — the widest change (20 files) but shallow. `Toaster` is a
singleton with `toast(title, message, icon, type?)` and a `toasts` array.
`Toast` is an object with `type`, `icon`, `title`, `message`, `closed`,
`close()`, `lock(target)`, `unlock(target)`, and four enum values (`Success`,
`Warning`, `Error`, `Info`). `lock`/`unlock` exist so a hovered toast does not
expire — that behaviour must survive. Enum values become an `enum` in the QML
component, keeping `Toast.Error` call sites unchanged.

**`FileSystemModel` / `FileSystemEntry`** — three instantiations. Model
properties: `path`, `recursive`, `filter` (with a static `Images` value),
`nameFilters`, `sortReverse`, and an `onPathChanged` handler. Entry members:
`path`, `name`, `isDir`, `baseName`, `relativePath`. Built on
`Quickshell.Io` — a `Process` listing plus a `ListModel`, or Qt's
`FolderListModel` where recursion is not needed.

**`CircularBuffer`** — `capacity`, `push(value)`, `maximum`, `count`, and a
`valuesChanged` signal. A JS ring buffer in a `QtObject`. Note `maximum`,
`count` and `valuesChanged` are consumed **cross-file** from
`modules/dashboard/Performance.qml` and `modules/bar/popouts/NetworkSpeed.qml`
via `NetworkUsage.downloadBuffer.*`, so the property names are a contract.

**`AppDb`** — set `path`, `favouriteApps`, `entries`; read `.apps`. Its
`entries` is already fed from Quickshell's native
`DesktopEntries.applications.values`, so this is not an app database at all —
it is sorting and filtering over the native one, with favourites ordering.
`utils/Searcher.qml` already exists and should supply the matching.

**`ServiceRef`** — `service` is set at four sites and never read. It is a
refcount that keeps a service alive while a consumer is mounted. The
replacement must preserve that lifecycle meaning; if `services/Audio.qml` is
restructured so `cava` and `beatTracker` start and stop on demand by their own
logic, `ServiceRef` may be deleted rather than reimplemented. Decide during
implementation, with evidence that the processes still stop when nothing is
watching.

### Involved — the two that need care

**`HyprExtras` / `HyprKeyboard`** (`services/Hypr.qml`) — the most technical
piece. `HyprExtras` supplies `devices`, `options`, `batchMessage([...])`,
`refreshDevices()`, and `message(cmd)`; `HyprKeyboard` supplies `capsLock`,
`numLock`, `layout`, `activeKeymap`, `main`. Quickshell's native
`Quickshell.Hyprland` provides IPC and event handling; the keyboard state and
device tree come from `devices`/`getoption` IPC calls parsed as JSON.
`batchMessage` matters for atomicity — several IPC commands in one round trip —
and must not degrade into a loop of individual calls where the current code
relies on them applying together.

Note `message()` is called cross-file as `Hypr.extras.message("reload")` from
`services/GameMode.qml`, one hop from the import site.

**`CircularIndicatorManager`** (`components/controls/CircularIndicator.qml`) —
eight members driving Material-style indeterminate progress:
`indeterminateAnimationType`, `progress`, `completeEndProgress`,
`completeEndDuration`, `rotation`, `startFraction`, `endFraction`, `duration`.
An animation state machine, expressible in QML `Behavior`/`Animator` but the
easiest place in this port to produce something that looks subtly wrong.
Verify against the current build visually, side by side.

## The CLI coupling the import scan missed

The reconnaissance behind this spec traced QML **imports**, so it did not see
`caelestia-cli`. The shell shells out to it at 14 sites, and removing the
plugin without replacing these leaves the shell just as coupled:

| Command | Sites | Replacement |
|---|---|---|
| `caelestia scheme set/get/list` | 6 — `services/Colours.qml:78`, `modules/launcher/services/Schemes.qml:43,67,85`, `modules/launcher/services/M3Variants.qml:82`, `modules/controlcenter/appearance/sections/{ColorSchemeSection.qml:46,ColorVariantSection.qml:41}` | Our own scheme store and `matugen` invocation |
| `caelestia wallpaper -f/-p/-r` | 3 — `services/Wallpapers.qml:24,85`, `config/LauncherConfig.qml:78` | Our own wallpaper setter |
| `caelestia record` | 3 — `services/Recorder.qml:54,58,62` | `wf-recorder` or `gpu-screen-recorder`, both already installed |
| `caelestia shell controlCenter open` | 1 — `config/LauncherConfig.qml:142` | Our own `IpcHandler`, which the shell already has |
| cosmetic strings | 2 — `components/misc/CustomShortcut.qml:4` (`appid`), `utils/SysInfo.qml:39` (logo name) | Rename |

`caelestia-cli` is a Python package; none of this is C++ and none of it needs
vendoring.

The scheme commands are the substantial ones: they own reading and writing the
colour scheme, listing available schemes and flavours, and setting the M3
variant. **The follow-on theming work replaces this layer wholesale** (see
below), so the port here should be the thinnest faithful equivalent that gets
the shell off the CLI — not a polished design. Do not gold-plate something
scheduled for replacement.

## External processes

Two features stay on their native libraries by running them as processes under
`Quickshell.Io` `Process` rather than linking them:

**Visualiser** — `cava` with a raw output config; parse bar values from stdout
into the existing `Audio.cava` shape. Same library, same FFT, across a pipe.
Already an installed dependency.

**BPM** — aubio's beat detection as a helper process feeding `bpm` back.
Consumed at exactly two sites (`modules/dashboard/Media.qml:400`,
`modules/dashboard/dash/Media.qml:216`), both setting the album-art GIF's
animation speed. `aubio` is already an installed dependency.

Both processes must start only when something is watching and stop when
nothing is — otherwise the port trades a linked library for two permanently
running audio analysers.

## Rollout

Incremental, plugin installed throughout, in ascending order of risk so the
easy work shakes out the pattern before the hard work depends on it:

1. Delete the three dead imports.
2. `IUtils`, `CUtils`, `Requests`, `Qalculator`, `ImageAnalyser`.
3. `CircularBuffer`, `FileSystemModel`/`Entry`, `ServiceRef`.
4. Toast system.
5. `AppDb`, `SparklineItem`, `CircularIndicatorManager`.
6. `HyprExtras`/`HyprKeyboard`, `LogindManager`.
7. `CavaProvider` and `BeatTracker` → helper processes.
8. Replace the `caelestia-cli` call sites: recording, wallpaper, the control
   centre IPC call, then the scheme commands.
9. Remove the dependency: drop `caelestia-shell` and `caelestia-cli`, unwind
   the `qs -c caelestia` config name and the
   `~/.config/quickshell/caelestia → jarvos` symlink, rename the `caelestia:`
   IPC keybind namespace to `jarvos:`.

After every step the shell must launch and the affected surface must work.

## Migration for existing machines

Step 8 ships as the first real migration, exercising the machinery cut at
v0.3.0. It must remove the packages, rewrite the config-name symlink, and
update keybinds — and it must no-op cleanly on a machine where a previous
attempt got partway. This is the first migration written in the `jarvos-pkg-*`
vocabulary and the first test of whether that vocabulary is sufficient; if it
is not, say so rather than working around it.

The keybind namespace rename touches user config that may have local
overrides in `hyprland/custom/`. Those are not tracked and must not be
clobbered.

## Verification

1. `grep -r 'import Caelestia' config/.config/quickshell/jarvos/` returns nothing.
2. The shell launches with `caelestia-shell` uninstalled, with no QML errors in
   `qs log -c caelestia -r '*=true'`.
3. Every surface touched works, checked against the current build: toasts
   (including hover-to-persist), launcher search and favourites, wallpaper
   grid, recordings list, file dialog, network sparklines, dashboard
   performance graphs, circular indicators, caps/num lock and keyboard layout,
   idle and lock behaviour, the visualiser, and BPM-driven GIF speed.
4. No audio analyser process runs when nothing is watching.
5. The migration takes an existing machine off the packages and is a clean
   no-op on second run.
6. `tests/run-all.sh` still passes.

## Follow-on: workspace-scoped job theming

Decided 2026-08-25, to be specced separately **after** this work lands. Noted
here because it determines how much effort the scheme port above deserves.

JarvOS will grow an omarchy-style theming system, expanded in two ways: themes
are bound to **job contexts** (bug bounty, development, CTF, DFIR and threat
hunting), and scoped to **Hyprland workspaces** rather than monitors.

Workspace scoping rather than per-monitor was chosen deliberately. Apps cannot
follow a monitor — a terminal does not know which screen it is on, and takes
its colours from its own config — so per-monitor theming could only ever have
covered shell chrome and wallpaper, while costing a refactor of the 1,222
`Colours.*` references currently reading a global singleton. Workspaces map to
jobs far better than monitors do, are already per-monitor in Hyprland, and can
theme the apps launched inside them.

Consequences for this spec: the scheme port in step 8 is throwaway
scaffolding. Keep it minimal.

## Open questions

- Whether `ServiceRef` is reimplemented or deleted — decide with evidence
  during step 3.
- Whether `Requests.resetCookies()` has real meaning in the lyrics flow or is
  vestigial; if vestigial, drop it rather than porting it.
- `modules/setup/Setup.qml` uses only two `Toaster.toast` calls, so it ports
  with the toast system. Retiring it is a separate question, not this work.
