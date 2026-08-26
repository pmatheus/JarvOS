# Caelestia Removal — Part 1: Test Harness and the Trivial Replacements

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-08-25-caelestia-removal-design.md` (steps 1–2 of its rollout)

**Goal:** Stand up QML unit testing, delete the three dead imports, and replace the five types whose entire surface is a handful of function calls — `IUtils`, `CUtils`, `Requests`, `Qalculator`, `ImageAnalyser`.

**Architecture:** Logic goes into `.pragma library` JS files, which Qt imports directly and `qmltestrunner` can exercise; the QML component becomes thin wiring over a tested core. The Caelestia plugin stays installed throughout — replacements carry different names, so each type migrates independently and every task is revertible alone.

**Tech Stack:** QML/Qt 6.11, `Quickshell.Io` (`Process`), Quickshell `ColorQuantizer`, `qalc`, `/usr/lib/qt6/bin/qmltestrunner`, the repo's existing bash test harness.

## Global Constraints

- **Use `/usr/lib/qt6/bin/qmltestrunner`, never `qmltestrunner` from `$PATH`.** The one on `$PATH` is Qt 5 (`qt5-declarative`) and fails **silently, exit 1, no output** against Qt 6 modules. Always run it under `QT_QPA_PLATFORM=offscreen`.
- **Do not rename anything.** `~/.config/caelestia/`, `qs -c caelestia`, the `caelestia:` keybind namespace, the `CAELESTIA_*` env vars and the paths in `utils/Paths.qml` all stay exactly as they are. That rename is a separate, later migration. This plan removes code dependencies only.
- **Do not uninstall `caelestia-shell` or `caelestia-cli`.** They stay until a later part.
- **Do not touch `services/Colours.qml`'s scheme handling or the `caelestia scheme` CLI calls.** Those belong to a later part and to the theming work.
- The repo is canonical; deploy to `~/.config/` is a separate `cp` step. Edit only `config/.config/quickshell/jarvos/`.
- `tests/run-all.sh` must pass after every task, with the existing suites unchanged: `jarvos-migrate: 24`, `jarvos-pkg: 12`, `jarvos-premark: 3`, `jarvos-state: 11`, `jarvos-version: 3`, `capture: 29`, `roundtrip: 20`.
- After every task the shell must still launch. Verify with `qs -c caelestia ipc call drawers toggle launcher` after restarting, and check `qs log -c caelestia -r '*=true'` for new QML errors.

---

## File Structure

| Path | Responsibility |
|---|---|
| `tests/qml/run.sh` | Runs every `tst_*.qml` under the Qt 6 runner, offscreen. |
| `tests/qml/tst_*.qml` | One suite per JS library. |
| `config/.config/quickshell/jarvos/utils/files.js` | Path and URL logic, unit-tested. |
| `config/.config/quickshell/jarvos/utils/Files.qml` | `CUtils`/`IUtils` replacement — wiring over `files.js`. |
| `config/.config/quickshell/jarvos/utils/Http.qml` | `Requests` replacement. |
| `config/.config/quickshell/jarvos/utils/Calc.qml` | `Qalculator` replacement over the `qalc` CLI. |
| `config/.config/quickshell/jarvos/utils/colour.js` | Luminance and dominant-colour maths, unit-tested. |

---

## Task 1: A QML test harness

**Files:**
- Create: `tests/qml/run.sh`
- Create: `tests/qml/tst_harness.qml`
- Modify: `tests/run-all.sh` — run the QML suite too

**Interfaces:**
- Produces: `tests/qml/run.sh`, exit 0 when every QML suite passes. Every later task adds a `tst_*.qml` beside it.

- [ ] **Step 1: Write the harness and a test that proves it runs**

Create `tests/qml/tst_harness.qml`:

```qml
// Proves the harness itself works: the Qt 6 runner, offscreen, finding suites.
// If this fails, nothing below it means anything.
import QtQuick
import QtTest

TestCase {
    name: "Harness"

    function test_runner_executes() {
        compare(1 + 1, 2);
    }

    function test_js_library_imports() {
        // The whole strategy rests on Qt resolving a .js import with no
        // qmldir and no module registration. If this breaks, the plan's
        // testing approach breaks with it.
        verify(typeof Qt.rect === "function");
    }
}
```

Create `tests/qml/run.sh`:

```bash
#!/usr/bin/env bash
# Run the QML unit suites.
#
# MUST use the Qt 6 runner explicitly: /usr/bin/qmltestrunner is Qt 5, from
# qt5-declarative, and fails silently with exit 1 and no output at all
# against Qt 6 modules. That failure looks exactly like "no tests found".
#
# Only .js libraries are unit-testable. QML components importing qs.* are not
# loadable here — qs.* is a Quickshell convention plain Qt cannot resolve.

set -uo pipefail

RUNNER=/usr/lib/qt6/bin/qmltestrunner
HERE="$(cd "$(dirname "$0")" && pwd)"
SHELL_ROOT="$(cd "$HERE/../../config/.config/quickshell/jarvos" && pwd)"

if [[ ! -x "$RUNNER" ]]; then
    echo "qml: $RUNNER not found — install qt6-declarative" >&2
    exit 1
fi

QT_QPA_PLATFORM=offscreen "$RUNNER" -input "$HERE" -import "$SHELL_ROOT"
```

- [ ] **Step 2: Run it and watch it pass**

Run: `chmod +x tests/qml/run.sh && tests/qml/run.sh`

Expected: `Totals: 4 passed, 0 failed`, exit 0.

- [ ] **Step 3: Prove the harness actually fails on a failure**

A green harness that cannot go red is worthless. Temporarily change `compare(1 + 1, 2)` to `compare(1 + 1, 3)`.

Run: `tests/qml/run.sh; echo "exit=$?"`

Expected: `FAIL!` and a non-zero exit. Revert the change and confirm green again.

- [ ] **Step 4: Wire it into the main suite**

In `tests/run-all.sh`, add the QML suite alongside the bash suites. Follow the file's existing structure for running a suite and reporting its result; if it collects suites by globbing `tests/*.test.sh`, add an explicit call for `tests/qml/run.sh` rather than renaming the QML runner to match that glob — it is not a bash suite and does not source `sandbox.sh`.

- [ ] **Step 5: Run everything and commit**

Run: `tests/run-all.sh`

Expected: every bash suite at its existing total, the QML suite passing, `shellcheck` clean, exit 0.

```bash
git add tests/qml tests/run-all.sh
git commit -m "test: add a QML unit harness

Logic being extracted from the Caelestia plugin needs somewhere to be
tested. .pragma library JS files import directly under Qt with no qmldir
and no module registration, so they are unit-testable; QML components
importing qs.* are not, because qs.* is a Quickshell convention plain Qt
cannot resolve.

Pins the Qt 6 runner explicitly. /usr/bin/qmltestrunner is Qt 5 from
qt5-declarative and fails silently with exit 1 and no output against Qt 6
modules, which is indistinguishable from finding no tests."
```

---

## Task 2: Delete the three dead imports

**Files:**
- Modify: `config/.config/quickshell/jarvos/modules/controlcenter/appearance/AppearancePane.qml`
- Modify: `config/.config/quickshell/jarvos/modules/controlcenter/components/WallpaperGrid.qml`
- Modify: `config/.config/quickshell/jarvos/modules/utilities/cards/RecordingList.qml`

Three files import a Caelestia module and use nothing from it. Free deletions, and they shrink the surface before any real work starts.

- [ ] **Step 1: Confirm each is genuinely unused before deleting**

For each file, confirm no type from that module appears. Do not trust the spec — verify:

```bash
cd config/.config/quickshell/jarvos
for f in modules/controlcenter/appearance/AppearancePane.qml \
         modules/controlcenter/components/WallpaperGrid.qml; do
    echo "=== $f"
    grep -nE 'AppDb|AppEntry|FileSystemModel|FileSystemEntry' "$f" || echo "  clean"
done
echo "=== RecordingList.qml (plain Caelestia import only)"
grep -nE 'CUtils|IUtils|Toast|Toaster|Requests|Qalculator|ImageAnalyser|AppDb' \
    modules/utilities/cards/RecordingList.qml || echo "  clean"
```

Expected: `clean` for all three. If anything is found, stop and report — the spec is wrong.

Note `RecordingList.qml` has **two** Caelestia imports. Only the plain `import Caelestia` goes; its `import Caelestia.Models` is live and stays.

- [ ] **Step 2: Delete the three import lines**

Remove `import Caelestia.Models` from `AppearancePane.qml` and `WallpaperGrid.qml`, and the plain `import Caelestia` from `RecordingList.qml`.

- [ ] **Step 3: Verify the shell still runs**

Run: `cp -rf config/.config/quickshell/jarvos/. ~/.config/quickshell/jarvos/ && systemctl --user restart quickshell-jarvos.service && sleep 3 && qs log -c caelestia -r '*=true' 2>&1 | tail -30`

Expected: no QML errors mentioning these three files. Then open the control centre appearance pane, the wallpaper grid, and the recordings list and confirm each still renders.

- [ ] **Step 4: Commit**

```bash
git add config/.config/quickshell/jarvos
git commit -m "refactor(shell): drop three unused Caelestia imports

AppearancePane and WallpaperGrid import Caelestia.Models and use no type
from it; RecordingList imports plain Caelestia and uses nothing from it,
though its separate Caelestia.Models import is live and stays."
```

---

## Task 3: `utils/Files.qml` — replace `CUtils` and `IUtils`

**Files:**
- Create: `config/.config/quickshell/jarvos/utils/files.js`
- Create: `config/.config/quickshell/jarvos/utils/Files.qml`
- Create: `tests/qml/tst_files.qml`
- Modify: `utils/Paths.qml`, `modules/dashboard/Wrapper.qml`, `modules/areapicker/Picker.qml`, `modules/utilities/RecordingDeleteModal.qml`, `services/Notifs.qml`, `components/images/CachingImage.qml`

**Interfaces:**
- Consumes: the Task 1 harness.
- Produces: `Files` singleton with `toLocalFile(url)`, `urlForPath(path, fillMode)`, `copyFile(src, dest)`, `deleteFile(url)`, `saveItem(item, dest, rect, callback)`.

The five call sites are `CUtils.saveItem` (`Picker.qml:77`, `Notifs.qml:244`), `CUtils.copyFile` (`Wrapper.qml:27`), `CUtils.deleteFile` (`RecordingDeleteModal.qml:187`), `CUtils.toLocalFile` (`Paths.qml:27`), and `IUtils.urlForPath` (`CachingImage.qml:12`).

- [ ] **Step 1: Write the failing tests for the pure logic**

Create `tests/qml/tst_files.qml`:

```qml
import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/files.js" as Files

TestCase {
    name: "Files"

    function test_toLocalFile_strips_the_scheme() {
        compare(Files.toLocalFile("file:///home/user/a.png"), "/home/user/a.png");
    }

    function test_toLocalFile_passes_through_a_bare_path() {
        compare(Files.toLocalFile("/home/user/a.png"), "/home/user/a.png");
    }

    function test_toLocalFile_of_empty_is_empty() {
        compare(Files.toLocalFile(""), "");
    }

    function test_urlForPath_adds_the_scheme() {
        compare(Files.urlForPath("/home/user/a.png"), "file:///home/user/a.png");
    }

    function test_urlForPath_leaves_an_existing_url_alone() {
        compare(Files.urlForPath("file:///home/user/a.png"), "file:///home/user/a.png");
    }

    function test_urlForPath_of_empty_is_empty() {
        compare(Files.urlForPath(""), "");
    }

    function test_a_path_with_spaces_round_trips() {
        const p = "/home/user/my wallpapers/a b.png";
        compare(Files.toLocalFile(Files.urlForPath(p)), p);
    }
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `tests/qml/run.sh`

Expected: failures — `files.js` does not exist.

- [ ] **Step 3: Write `utils/files.js`**

Create `config/.config/quickshell/jarvos/utils/files.js`:

```javascript
.pragma library

// Path and URL conversion, kept out of QML so it can be unit-tested.
// Percent-encoding matters: wallpaper directories routinely have spaces.

function toLocalFile(url) {
    if (!url)
        return "";
    const s = url.toString();
    if (!s.startsWith("file://"))
        return s;
    return decodeURIComponent(s.slice("file://".length));
}

function urlForPath(path) {
    if (!path)
        return "";
    const s = path.toString();
    if (s.includes("://"))
        return s;
    return "file://" + encodeURI(s);
}
```

`urlForPath`'s second argument at the call site is `fillMode`, which the
Caelestia version used for cache-key purposes. Check `CachingImage.qml:12`:
if the value is not needed to produce the URL, do not invent a use for it —
drop it from the signature and from the call site.

- [ ] **Step 4: Run and watch it pass**

Run: `tests/qml/run.sh`

Expected: `Files` suite green.

- [ ] **Step 5: Write `utils/Files.qml`**

Create `config/.config/quickshell/jarvos/utils/Files.qml` as a `pragma Singleton` matching the shape of the other singletons in `utils/`. It exposes the two tested JS functions, plus the three that need Qt:

- `copyFile(src, dest)` and `deleteFile(url)` — via `Quickshell.Io` `Process` (`cp`, `rm`), returning success the way the call sites expect. Note `Wrapper.qml:27` uses the return value in an `if`, so it needs a synchronous-looking boolean or the call site must be adapted to a callback; read that site before choosing.
- `saveItem(item, dest, rect, callback)` — `item.grabToImage(result => { result.saveToFile(path); callback(path) })`. `Picker.qml:77` passes a `Qt.rect(...)`; `grabToImage` has no crop, so crop by grabbing then saving a cropped copy, or grab a wrapper sized to the rect. Read both call sites before choosing.

- [ ] **Step 6: Migrate the six call sites**

Replace each `CUtils.*`/`IUtils.*` with `Files.*`, and swap the `import Caelestia`/`import Caelestia.Images` for `import qs.utils` where that import is not already present. Leave any other Caelestia import in those files alone — several use `Toaster` too, which is a later task.

- [ ] **Step 7: Verify behaviour, not just startup**

Deploy and restart as in Task 2, then exercise each path for real:
- area picker: take a region screenshot, confirm the file is written and correct
- notification image caching: trigger a notification with an image
- recordings: delete a recording from the utilities card
- wallpapers: confirm they still resolve and render (`Paths.toLocalFile`)
- dashboard: whatever `Wrapper.qml:27`'s `copyFile` feeds

Expected: all work, no new QML errors in `qs log`.

- [ ] **Step 8: Commit**

```bash
git add config/.config/quickshell/jarvos tests/qml
git commit -m "refactor(shell): replace CUtils and IUtils with utils/Files

Five call sites across four members plus one URL helper. The path and URL
conversion lives in files.js and is unit-tested — percent-encoding is the
part that actually breaks, since wallpaper directories routinely contain
spaces. The file operations are Process calls and grabToImage."
```

---

## Task 4: `utils/Http.qml` — replace `Requests`

**Files:**
- Create: `config/.config/quickshell/jarvos/utils/Http.qml`
- Modify: `services/Weather.qml`, `services/LyricsService.qml`

**Interfaces:**
- Produces: `Http` singleton with `get(url, onSuccess, onError)`.

Seven call sites: `Weather.qml:40,61,74,91,109` (the one at 74 passes an error callback) and `LyricsService.qml:235,286`, plus `LyricsService.qml:231`'s `resetCookies()`.

- [ ] **Step 1: Establish what `resetCookies` actually does**

Before writing anything, determine whether `resetCookies()` has real meaning in the lyrics flow or is vestigial. Read `services/LyricsService.qml` around line 231 and trace what breaks without it.

QML's `XMLHttpRequest` does not share a cookie jar the way a browser does, so the call may be meaningless in the replacement. **Report the finding.** If it is vestigial, drop it rather than porting it; if it is load-bearing, say what it is load-bearing for before implementing anything.

- [ ] **Step 2: Count the real call sites**

The recon behind the spec read only excerpts of `LyricsService.qml` and flagged its own count as unverified.

Run: `grep -n 'Requests\.' config/.config/quickshell/jarvos/services/LyricsService.qml config/.config/quickshell/jarvos/services/Weather.qml`

Use what this prints, not the spec's number.

- [ ] **Step 3: Write `utils/Http.qml`**

A `pragma Singleton` wrapping `XMLHttpRequest`:

```qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // onError is optional: most call sites pass only onSuccess, and a
    // failed request there should stay silent rather than throw.
    function get(url: string, onSuccess: var, onError: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300)
                onSuccess?.(xhr.responseText);
            else
                onError?.(xhr.status, xhr.responseText);
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
```

Check what the existing call sites pass their success callback — a string, or parsed JSON. Match it exactly; do not change the contract while replacing the implementation.

- [ ] **Step 4: Migrate the call sites and verify against the network**

Replace `Requests.get` with `Http.get`, adjust imports.

Verify for real, not just that the shell starts: weather must fetch and display, including the nominatim path at `Weather.qml:74` that has the error callback — force that error branch if you can. Lyrics must fetch for a playing track.

Expected: both surfaces populate, no new QML errors.

- [ ] **Step 5: Commit**

```bash
git add config/.config/quickshell/jarvos
git commit -m "refactor(shell): replace Requests with utils/Http

XMLHttpRequest covers get(); the callback contract at each site is
preserved exactly rather than tidied while replacing the implementation."
```

Note in the commit body what Step 1 concluded about `resetCookies`.

---

## Task 5: `utils/Calc.qml` — replace `Qalculator`

**Files:**
- Create: `config/.config/quickshell/jarvos/utils/Calc.qml`
- Modify: `modules/launcher/items/CalcItem.qml`

**Interfaces:**
- Produces: `Calc` singleton with `eval(expr, callback)`.

Two call sites, both in `CalcItem.qml` (lines 16 and 58). `libqalculate` is already an installed dependency, and the `qalc` CLI ships with it.

- [ ] **Step 1: Confirm the CLI contract**

Run: `qalc -t "2+2"` and `qalc -t "1/0"` and `qalc -t "not maths"`

Expected: `4` for the first. **Record what the other two actually print and what they exit with** — the error behaviour determines what the launcher shows for a partial expression, which is the common case while typing.

- [ ] **Step 2: Read the call sites before designing the signature**

`Qalculator.eval(math, false)` at line 16 and `Qalculator.eval(root.math)` at line 58. The second argument is a `showResult` flag. Determine what the false value changes, and whether the existing call is synchronous — `Process` is asynchronous, so if `CalcItem.qml` uses the return value inline, the call site needs a callback and a property to bind to.

**This is the substantive part of the task.** Report the shape before implementing.

- [ ] **Step 3: Write `utils/Calc.qml`**

A `pragma Singleton` running `qalc -t <expr>` through `Quickshell.Io` `Process`, collecting stdout, and delivering the result through a callback or a bindable property depending on Step 2. Expressions come from user typing, so pass the expression as a **separate argv element**, never interpolated into a shell string.

- [ ] **Step 4: Verify in the launcher**

Deploy, restart, open the launcher and type an expression. Check: a complete expression gives the right answer; a partial expression while typing does not error or flicker; a nonsense expression degrades the way it did before.

- [ ] **Step 5: Commit**

```bash
git add config/.config/quickshell/jarvos
git commit -m "refactor(shell): replace Qalculator with the qalc CLI

libqalculate was already a dependency; this drops the plugin binding and
keeps the library. The expression is passed as its own argv element rather
than interpolated, since it comes straight from user typing."
```

---

## Task 6: Replace `ImageAnalyser`

**Files:**
- Create: `config/.config/quickshell/jarvos/utils/colour.js`
- Create: `tests/qml/tst_colour.qml`
- Modify: `services/Colours.qml`, `components/effects/ColouredIcon.qml`

**Interfaces:**
- Produces: luminance and dominant-colour helpers in `colour.js`, and `ColorQuantizer` wiring at the two sites.

Two call sites with **different shapes**, which is the whole difficulty:
- `services/Colours.qml:88` — `ImageAnalyser { source: Wallpapers.current }`, reads `.luminance`. A URL source.
- `components/effects/ColouredIcon.qml:30` — `ImageAnalyser { sourceItem: root }`, reads `.dominantColour`, calls `.requestUpdate()`. A live QML **Item**, not a URL.

Quickshell's `ColorQuantizer` takes `source` (a `QUrl`), `depth`, and exposes `colors`. **It has no `sourceItem`.** The `ColouredIcon` case therefore needs `grabToImage()` to produce an image first, then quantisation over that — or a different approach entirely.

- [ ] **Step 1: Write the failing tests for the colour maths**

Create `tests/qml/tst_colour.qml`:

```qml
import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/colour.js" as Colour

TestCase {
    name: "Colour"

    function test_luminance_of_black_is_zero() {
        compare(Colour.luminance(0, 0, 0), 0);
    }

    function test_luminance_of_white_is_one() {
        fuzzyCompare(Colour.luminance(1, 1, 1), 1, 0.001);
    }

    function test_green_reads_brighter_than_blue() {
        // Perceptual weighting, not a plain average — a mid green must come
        // out brighter than a mid blue or every light/dark decision downstream
        // is wrong.
        verify(Colour.luminance(0, 0.5, 0) > Colour.luminance(0, 0, 0.5));
    }

    function test_dominant_of_an_empty_list_is_null() {
        compare(Colour.dominant([]), null);
    }

    function test_dominant_returns_the_first_quantised_colour() {
        compare(Colour.dominant(["#ff0000", "#00ff00"]), "#ff0000");
    }
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `tests/qml/run.sh`

Expected: failures — `colour.js` does not exist.

- [ ] **Step 3: Write `utils/colour.js`**

```javascript
.pragma library

// Relative luminance, Rec. 709 weighting. Kept out of QML so the weighting
// is pinned by a test: a plain average would make greens read too dark and
// flip light/dark decisions across the shell.
function luminance(r, g, b) {
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function dominant(colours) {
    return colours && colours.length ? colours[0] : null;
}
```

Confirm against the existing behaviour: `Colours.qml:27`'s `getLuminance` may already use a specific formula. **Match what the shell does today** — if it uses a different weighting, use that and adjust the test, rather than changing appearance while replacing a dependency.

- [ ] **Step 4: Run and watch it pass**

Run: `tests/qml/run.sh`

Expected: `Colour` suite green.

- [ ] **Step 5: Replace the URL-source site**

In `services/Colours.qml`, swap `ImageAnalyser { source: ... }` for `ColorQuantizer { source: ...; depth: ... }` and derive `luminance` from its `colors` via `colour.js`. Pick `depth` by comparing the resulting `wallLuminance` against the current build on several wallpapers.

**Correction, made during implementation:** an earlier draft of this step claimed `wallLuminance` feeds light/dark decisions shell-wide. It does not. Light/dark comes from the `mode` in `scheme.json`; `wallLuminance` has exactly one consumer, the transparency offset in `alterColour` at `services/Colours.qml:36`. The value still needs to match, but a shift in it changes layer transparency, not the shell's mode.

The plugin's formula — read off its source, not inferred — is `sqrt(0.299r² + 0.587g² + 0.114b²)` averaged over every opaque pixel, which is the same expression as this file's own `getLuminance` and **not** the Rec. 709 average suggested in Step 3 below. Reproduce the existing one.

- [ ] **Step 6: Replace the Item-source site**

`ColouredIcon.qml` needs the icon's rendered pixels. `grabToImage()` gives an `ImageGrabResult`; save it or use its `url` as the quantizer's `source`. `requestUpdate()` becomes a re-grab.

If this proves unworkable, **stop and report** rather than forcing it — an acceptable alternative is deriving the colour from the icon's source URL instead of its rendered form, but that is a behaviour change and needs saying out loud, not slipping in.

- [ ] **Step 7: Verify visually**

Deploy and restart. Compare against the current build:
- light and dark wallpapers still flip the shell's light/dark mode at the same point
- coloured icons still tint correctly, including after an icon changes

Expected: no visible difference. This is the task most likely to look subtly wrong rather than break.

- [ ] **Step 8: Commit**

```bash
git add config/.config/quickshell/jarvos tests/qml
git commit -m "refactor(shell): replace ImageAnalyser with ColorQuantizer

Two sites with different shapes: Colours.qml analyses a wallpaper URL,
which ColorQuantizer takes directly, while ColouredIcon analyses a live
QML Item, which it does not — that one grabs the item to an image first.

The luminance weighting is pinned by a test because it decides light/dark
across the whole shell, and a plain average would make greens read dark."
```

---

## Done when

- `tests/qml/run.sh` passes and is wired into `tests/run-all.sh`.
- `tests/run-all.sh` exits 0 with the bash suites at their existing totals.
- `grep -rn 'CUtils\|IUtils\|Requests\.\|Qalculator\|ImageAnalyser' config/.config/quickshell/jarvos/` returns nothing.
- Three dead imports are gone.
- The shell launches, `qs log -c caelestia -r '*=true'` shows no new QML errors, and every surface listed in the verification steps works.
- `caelestia-shell` is still installed and the `caelestia` name is untouched everywhere.

## Findings to act on separately

**Nominatim reverse-geocoding has always been failing.** Discovered during
Task 4 and confirmed independently: `nominatim.openstreetmap.org` returns 403
with no User-Agent **and** 403 for a generic `Mozilla/5.0`, but 200 for an
identifying one such as `JarvOS/0.3.0 (desktop shell)`. The shell has therefore
always fallen through to BigDataCloud at `services/Weather.qml:74` — the
"fallback" is the live path and the primary geocoder never worked.

This predates the port and was not caused by it. Task 4 deliberately did not
fix it: that task's contract is to replace the implementation without changing
behaviour. Now that `Http.get` takes a headers argument the fix is one call
site, but it changes which geocoding service answers, so it is its own change
with its own verification. Note that Nominatim's usage policy requires an
identifying User-Agent and rate-limits clients.

**The region-screenshot crop from Task 3 is unverified.** It cannot be
exercised without a human drag — the picker is reachable over IPC but
`hypr-box input click` has no press-and-hold primitive. Needs one manual
region screenshot to confirm the output matches the selected rectangle rather
than the full screen.

## Handoff to Part 2

Record for the next plan:
- what Step 1 of Task 4 concluded about `resetCookies`
- the `qalc` error-path behaviour from Task 5 Step 1
- whether `ColouredIcon` kept Item-based analysis or moved to its source URL
- the `depth` value chosen for `ColorQuantizer` and how it was validated

Part 2 covers `CircularBuffer`, `FileSystemModel`/`FileSystemEntry`, `ServiceRef`, and the toast system.
