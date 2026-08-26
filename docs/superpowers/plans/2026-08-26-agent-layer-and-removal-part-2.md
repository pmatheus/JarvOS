# Agent Layer + Caelestia Removal Part 2 — combined plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Specs:** `docs/superpowers/specs/2026-08-26-agent-layer-design.md` and `docs/superpowers/specs/2026-08-25-caelestia-removal-design.md` (step 3 of its rollout, plus the toast system).

**Goal:** Land the agent layer's command-line half, and replace the next four Caelestia types.

**Architecture:** Two tracks over disjoint trees. **Track A** is `bin/`, `config/.config/jarvos/`, one line of `keybinds.conf`. **Track B** is `config/.config/quickshell/jarvos/`. The only file either track shares is `modules/bar/popouts/kblayout/KbLayoutModel.qml`, which Track B's toast task edits and Track A never touches. Tasks within a track are ordered; across tracks they are independent and may run concurrently.

**Tech Stack:** bash 5 + the existing `tests/lib/sandbox.sh` harness for Track A; QML/Qt 6.11 with `.pragma library` JS + `/usr/lib/qt6/bin/qmltestrunner` for Track B.

## Global Constraints

- **Never break an existing keybinding.** The keymap is 108 bindings deep. This plan repoints exactly one (`Super+A`) and adds none.
- **`Super+A` must behave identically after Task 2 as before it**, because the shipped default is `claude-desktop`. That is the acceptance test, not a nicety.
- **Offer, never act.** No failure handoff runs an agent unattended.
- **No secrets in prompts or logs.** Nothing generated here may embed a token. Invoke the `vault-working` skill before touching anything under `~/.secrets/` or any `.env*`.
- **Do not touch `hypr-box`**, `services/Colours.qml`'s scheme handling, or any `caelestia scheme` CLI call.
- **Do not rename anything.** `~/.config/caelestia/`, `qs -c caelestia`, the `caelestia:` keybind namespace and `CAELESTIA_*` env vars all stay — that rename is a separate later migration.
- **Do not uninstall `caelestia-shell` or `caelestia-cli`.**
- QML unit tests use `/usr/lib/qt6/bin/qmltestrunner`. **Never bare `qmltestrunner`** — that is Qt 5 and fails silently with exit 1 and no output.
- `tests/run-all.sh` takes ~4 minutes under current machine load. Run it in the background; truncated output is not evidence of failure.
- Current totals, all must hold: `jarvos-hook: 9`, `jarvos-migrate: 24`, `jarvos-package: 10`, `jarvos-pkg: 12`, `jarvos-premark: 3`, `jarvos-refresh-config: 11`, `jarvos-state: 11`, `jarvos-update: 12`, `jarvos-update-steps: 15`, `jarvos-version: 3`, `capture: 29`, `roundtrip: 20`, QML **43**, shellcheck clean.

---

## File Structure

| Path | Responsibility |
|---|---|
| `bin/jarvos-default-agent` | Read or set the chosen agent. |
| `bin/jarvos-agent` | Launch it — GUI directly, CLI in a terminal. |
| `bin/jarvos-agent-prompt` | Hand a prompt to the launcher. |
| `bin/jarvos-agent-diagnose` | Gather a failure's facts, point at a skill, offer it to the agent. |
| `config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md` | The method, edited in one place. |
| `tests/jarvos-agent.test.sh` | Track A suite. |
| `.../jarvos/utils/circularbuffer.js`, `utils/CircularBuffer.qml` | Ring buffer. |
| `.../jarvos/utils/filesystem.js`, `utils/FileSystemModel.qml` | Directory listing model. |
| `.../jarvos/components/misc/ServiceRef.qml` | Service lifetime, or deleted. |
| `.../jarvos/services/Toaster.qml`, `components/misc/Toast.qml`, `utils/toast.js` | Toast system. |

---

# Track A — the agent layer

## Task 1: `jarvos-default-agent`

**Files:** Create `bin/jarvos-default-agent`, `tests/jarvos-agent.test.sh`.

**Interfaces:** Produces `jarvos-default-agent` — no args prints the current agent, one arg sets it. Stored at `$XDG_CONFIG_HOME/jarvos/defaults/agent`. Tasks 2-4 consume it.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-agent.test.sh`:

```bash
#!/usr/bin/env bash
# The agent layer: which agent is yours, and launching it.
# Run: tests/jarvos-agent.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

AGENT_FILE="$FAKE_HOME/.config/jarvos/defaults/agent"

start_test "with nothing set, the default is claude-desktop"
# NOT silent-when-unset like omarchy: Super+A already launches Claude Desktop
# today, and repointing that key must not change what it does.
run_cmd jarvos-default-agent
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "claude-desktop" &&
    pass_test

start_test "setting an agent records it"
run_cmd jarvos-default-agent codex
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$AGENT_FILE" &&
    assert_contains "$AGENT_FILE" "codex" &&
    pass_test

start_test "and reading it back returns what was set"
run_cmd jarvos-default-agent
assert_stdout_contains "$RUN_OUT" "codex" && pass_test

start_test "an alias resolves to its canonical name"
run_cmd jarvos-default-agent claude-code
assert_contains "$AGENT_FILE" "claude" &&
    { grep -qx 'claude-code' "$AGENT_FILE" && fail_test "stored the alias, not the canonical name"; } || pass_test

start_test "an unknown agent is refused and does not overwrite the current one"
run_cmd jarvos-default-agent definitely-not-an-agent
assert_status "$RUN_STATUS" 1 &&
    assert_contains "$AGENT_FILE" "claude" &&
    pass_test

start_test "the error names what is available"
assert_stdout_contains "$RUN_OUT" "codex" && pass_test

start_test "--list prints every supported agent"
run_cmd jarvos-default-agent --list
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "claude-desktop" &&
    assert_stdout_contains "$RUN_OUT" "opencode" &&
    pass_test

summary "jarvos-agent"
```

- [ ] **Step 2: Run it and watch it fail**

Run: `chmod +x tests/jarvos-agent.test.sh && tests/jarvos-agent.test.sh`

Expected: every case FAILs — the command does not exist.

- [ ] **Step 3: Write `bin/jarvos-default-agent`**

```bash
#!/usr/bin/env bash
# jarvos-default-agent [--list] [<agent>]
#
# jarvos:summary=Read or set the coding agent Super+A launches
# jarvos:args=[--list] [claude-desktop|claude|codex|opencode|antigravity]
# jarvos:examples=jarvos-default-agent | jarvos-default-agent codex
#
# The names map to what system/modules/ai.module actually installs. Unlike
# omarchy, which ships no default and makes you choose, JarvOS defaults to
# claude-desktop: Super+A already launches it, and repointing that key at this
# launcher must not change what the key does.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

DEFAULT_AGENT=claude-desktop
AGENT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/jarvos/defaults/agent"

canonical() {
    case "$1" in
        claude-desktop | desktop) echo claude-desktop ;;
        claude | claude-code) echo claude ;;
        codex | openai-codex) echo codex ;;
        opencode | open-code) echo opencode ;;
        antigravity | agy) echo antigravity ;;
        *) return 1 ;;
    esac
}

case "${1-}" in
--list)
    printf '%s\n' claude-desktop claude codex opencode antigravity
    exit 0
    ;;
-h | --help)
    sed -n '2,12p' "$0"
    exit 0
    ;;
"")
    if [[ -r "$AGENT_FILE" ]]; then
        read -r agent <"$AGENT_FILE"
    fi
    printf '%s\n' "${agent:-$DEFAULT_AGENT}"
    exit 0
    ;;
esac

name="$(canonical "$1")" || die "unknown agent: $1 (see: jarvos-default-agent --list)"

mkdir -p "$(dirname "$AGENT_FILE")"
printf '%s\n' "$name" >"$AGENT_FILE"
```

- [ ] **Step 4: Run and watch it pass**

Run: `chmod +x bin/jarvos-default-agent && tests/jarvos-agent.test.sh`

Expected: `jarvos-agent: 7 passed, 0 failed`.

- [ ] **Step 5: Register the suite and commit**

Confirm `tests/run-all.sh` picks it up via its `tests/*.test.sh` glob, then run the full suite in the background.

```bash
git add bin/jarvos-default-agent tests/jarvos-agent.test.sh
git commit -m "feat(agent): add jarvos-default-agent

Which coding agent is yours, stored in ~/.config/jarvos/defaults/agent.

Defaults to claude-desktop rather than being unset. omarchy deliberately
ships no default and makes you choose; here Super+A already launches Claude
Desktop, and the next task repoints that key at this launcher — so the
default exists to keep the key doing exactly what it does today."
```

---

## Task 2: `jarvos-agent` and repointing `Super+A`

**Files:** Create `bin/jarvos-agent`. Modify `config/.config/hypr/hyprland/keybinds.conf` (one line), `tests/jarvos-agent.test.sh`.

**Interfaces:** Produces `jarvos-agent [--pick] [--prompt TEXT]`. Task 3 and Task 4 call it.

- [ ] **Step 1: Record exactly what `Super+A` does today**

This is the baseline the change is measured against. Run:

`grep -n 'Super, A' config/.config/hypr/hyprland/keybinds.conf`

Paste the result into your report. The command it runs is what `jarvos-agent` must produce for the `claude-desktop` agent, flags included.

- [ ] **Step 2: Append the failing tests**

Add to `tests/jarvos-agent.test.sh` before `summary`:

```bash
# --- launching -----------------------------------------------------------

: >"$FAKE_STATE/launched"
cat >"$FAKE_BIN/claude-desktop-native" <<'EOF'
#!/usr/bin/env bash
printf 'claude-desktop-native %s\n' "$*" >> "$FAKE_STATE/launched"
EOF
cat >"$FAKE_BIN/kitty" <<'EOF'
#!/usr/bin/env bash
printf 'kitty %s\n' "$*" >> "$FAKE_STATE/launched"
EOF
chmod +x "$FAKE_BIN"/claude-desktop-native "$FAKE_BIN"/kitty

start_test "the shipped default launches Claude Desktop, as Super+A does today"
rm -f "$AGENT_FILE"
: >"$FAKE_STATE/launched"
run_cmd jarvos-agent
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/launched" "claude-desktop-native" &&
    pass_test

start_test "and it carries the ozone flags the old binding used"
assert_contains "$FAKE_STATE/launched" "ozone-platform=wayland" && pass_test

start_test "a CLI agent opens in a terminal instead"
run_cmd jarvos-default-agent codex
: >"$FAKE_STATE/launched"
run_cmd jarvos-agent
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/launched" "kitty" &&
    assert_contains "$FAKE_STATE/launched" "codex" &&
    pass_test

start_test "a prompt reaches the agent"
: >"$FAKE_STATE/launched"
run_cmd jarvos-agent --prompt "fix the thing"
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/launched" "fix the thing" &&
    pass_test

start_test "an agent that is not installed fails readably rather than silently"
run_cmd jarvos-default-agent opencode
run_cmd jarvos-agent
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero for a missing agent"; } &&
    assert_stdout_contains "$RUN_OUT" "opencode" &&
    pass_test

start_test "keybinds.conf routes Super+A through the launcher"
assert_contains "$REPO_ROOT/config/.config/hypr/hyprland/keybinds.conf" "jarvos-agent" && pass_test
```

- [ ] **Step 3: Run and watch the new cases fail**

Run: `tests/jarvos-agent.test.sh`

Expected: the first 7 pass, the 6 new ones FAIL.

- [ ] **Step 4: Write `bin/jarvos-agent`**

Launch a GUI agent directly; run a CLI agent inside a terminal. Reuse the repo's existing terminal-selection idiom rather than hardcoding one — read `config/.config/hypr/hyprland/scripts/launch_first_available.sh` and follow it.

For `claude-desktop`, reproduce **exactly** the command Step 1 recorded, flags included. A prompt is appended as the agent's argument for CLI agents; for `claude-desktop`, which takes no prompt argument, report that rather than dropping it silently.

Borrow omarchy's `cd` behaviour and its reason: agents will not remember trust for `$HOME`, so a keybinding launch should start somewhere stable. Use `$JARVOS_PATH` if it is a directory, else `$HOME` — do not invent a `~/Work`.

- [ ] **Step 5: Repoint `Super+A`**

In `keybinds.conf`, replace the `Super, A` line's exec with `jarvos-agent`, keeping the description text so the cheatsheet still reads correctly.

- [ ] **Step 6: Run the tests, then verify on the real machine**

Run: `tests/jarvos-agent.test.sh` — expected `13 passed, 0 failed`.

Then deploy and confirm the key genuinely still works:

```bash
cp -rf config/.config/hypr/. ~/.config/hypr/
hyprctl reload
```

Press `Super+A`. **Claude Desktop must open exactly as before.** If it does not, revert the keybinds change immediately and report — this is the one change in the plan that can disrupt daily use.

- [ ] **Step 7: Commit**

```bash
git add bin/jarvos-agent config/.config/hypr/hyprland/keybinds.conf tests/jarvos-agent.test.sh
git commit -m "feat(agent): add jarvos-agent and repoint Super+A through it

Super+A launched claude-desktop-native directly. It now launches whichever
agent is default, which ships as claude-desktop with the same ozone flags —
so the key does exactly what it did, and gains a switch.

GUI agents launch directly; CLI agents open in a terminal chosen the same
way the other keybindings choose one. A keybinding launch starts in the
JarvOS checkout rather than \$HOME, because agents will not remember trust
for \$HOME and would re-prompt every session."
```

---

## Task 3: `jarvos-agent-prompt`

**Files:** Create `bin/jarvos-agent-prompt`. Modify `tests/jarvos-agent.test.sh`.

**Interfaces:** `jarvos-agent-prompt <text>...` → `jarvos-agent --prompt`.

- [ ] **Step 1: Append the failing tests**

```bash
start_test "a prompt is passed through to the agent"
run_cmd jarvos-default-agent codex
: >"$FAKE_STATE/launched"
run_cmd jarvos-agent-prompt why is the build failing
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/launched" "why is the build failing" &&
    pass_test

start_test "an empty prompt is refused rather than opening an empty agent"
run_cmd jarvos-agent-prompt
assert_status "$RUN_STATUS" 1 && pass_test
```

- [ ] **Step 2: Run, see them fail, then write the command**

A thin wrapper joining `"$@"` into one prompt and `exec`ing `jarvos-agent --prompt`. Refuse an empty prompt — opening an agent with nothing to do is the behaviour the command exists to avoid.

- [ ] **Step 3: Run the tests, run the full suite, commit**

Expected: `15 passed, 0 failed`.

```bash
git add bin/jarvos-agent-prompt tests/jarvos-agent.test.sh
git commit -m "feat(agent): add jarvos-agent-prompt

Start work rather than open a tool. Refuses an empty prompt, since an agent
opened with nothing to do is exactly what this avoids."
```

---

## Task 4: Failure handoff — `jarvos-agent-diagnose` and the first skill

**Files:** Create `bin/jarvos-agent-diagnose`, `config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md`. Modify `bin/jarvos-update` (the `ERR` trap), `tests/jarvos-agent.test.sh`.

**Interfaces:** `jarvos-agent-diagnose <kind> [args]` where kind is `update`, `crash`, `migration` or `shell`. Prints the prompt with `--dry-run`; otherwise hands it to `jarvos-agent --prompt`.

This is the piece JarvOS is best positioned for: the failures are already instrumented. **The method lives in the skill; the script only gathers facts and points at it.**

- [ ] **Step 1: Append the failing tests**

```bash
# --- failure handoff -----------------------------------------------------

start_test "an update diagnosis names the transcript and the skill"
printf 'error: something broke\n' >"$FAKE_STATE/fake-update.log"
JARVOS_UPDATE_TRANSCRIPT="$FAKE_STATE/fake-update.log" \
    run_cmd jarvos-agent-diagnose update --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "something broke" &&
    assert_stdout_contains "$RUN_OUT" "SKILL.md" &&
    pass_test

start_test "--dry-run prints the prompt and launches nothing"
: >"$FAKE_STATE/launched"
JARVOS_UPDATE_TRANSCRIPT="$FAKE_STATE/fake-update.log" \
    run_cmd jarvos-agent-diagnose update --dry-run
{ [[ ! -s "$FAKE_STATE/launched" ]] || fail_test "--dry-run launched an agent"; } && pass_test

start_test "an unknown kind is refused"
run_cmd jarvos-agent-diagnose frobnicate
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a crash diagnosis carries the process facts"
run_cmd jarvos-agent-diagnose crash 1234 kitty /usr/bin/kitty SIGSEGV --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "1234" &&
    assert_stdout_contains "$RUN_OUT" "SIGSEGV" &&
    pass_test

start_test "the shipped skill exists where the prompt points"
assert_file_exists "$REPO_ROOT/config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md" &&
    pass_test

start_test "jarvos-update offers the diagnosis without running it"
assert_contains "$REPO_ROOT/bin/jarvos-update" "jarvos-agent-diagnose" && pass_test
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Write the skill**

Create `config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md`. It holds the *method*, so it is edited once and works with whichever agent is default. Cover: read the transcript before theorising; identify the failing step rather than the last line; distinguish a JarvOS defect from an upstream package failure; check whether the operation is safe to retry (`jarvos-update` resumes, migrations retry on the next run); and never re-run a failed update unattended.

Include the note omarchy uses: if the harness has no skill mechanism, read this file directly and follow it.

- [ ] **Step 4: Write `bin/jarvos-agent-diagnose`**

Per kind, gather facts and build a prompt:

| Kind | Facts |
|---|---|
| `update` | tail of `${JARVOS_UPDATE_TRANSCRIPT:-/tmp/jarvos-update.log}`, `jarvos-version` |
| `crash` | args: pid, comm, exe, signal; timestamp from `coredumpctl list <pid>` if available, failure tolerated |
| `migration` | migration filename, its output, which marker is absent |
| `shell` | bounded tail of `qs log -c caelestia` — **bound it, `qs log` follows by default** |

`--dry-run` prints the prompt and exits. Otherwise `exec jarvos-agent --prompt "$prompt"`.

**Never embed a token or a secret in a prompt.** Transcripts can contain anything the update printed; if a redaction pass is warranted, say so rather than shipping raw.

- [ ] **Step 5: Wire it into `jarvos-update`'s `ERR` trap**

`bin/jarvos-update:81`'s `on_error` already prints where the transcript is. Add one line offering the diagnosis — **printing the command, not running it**. An agent must not be launched unattended against a machine mid-failure.

- [ ] **Step 6: Run the tests, the full suite, and verify by hand**

Expected: `21 passed, 0 failed`.

By hand: force a failure with `JARVOS_MIN_FREE_GIB=999999 bin/jarvos-update -y` and confirm the output offers the diagnose command and does not execute it.

- [ ] **Step 7: Commit**

```bash
git add bin/jarvos-agent-diagnose bin/jarvos-update config/.config/jarvos/agents tests/jarvos-agent.test.sh
git commit -m "feat(agent): hand failures to the default agent with the facts gathered

jarvos-agent-diagnose collects what a failure left behind — an update
transcript, a coredump record, a migration's output, the shell log — and
hands it to whichever agent is default, pointing at a skill that holds the
method. The skill is edited in one place and works with any agent; a
harness without a skill mechanism is told to read the file directly.

It offers and never acts: jarvos-update's ERR trap prints the command
rather than running it. Launching an agent unattended against a machine
that is already mid-failure is not a recovery strategy.

This is the first skill JarvOS ships."
```

---

## Task 5: Command metadata across `bin/`

**Files:** Modify every `bin/jarvos-*` lacking the header.

Adopt the self-describing convention while there are 19 commands rather than 40. Nothing consumes it yet; it is what lets a menu or cheatsheet be generated later instead of hand-maintained.

- [ ] **Step 1: Write the failing test**

Append to `tests/jarvos-agent.test.sh`:

```bash
start_test "every jarvos command describes itself"
missing=""
for cmd in "$REPO_ROOT"/bin/jarvos-*; do
    grep -q '^# jarvos:summary=' "$cmd" || missing="$missing ${cmd##*/}"
done
[[ -z "$missing" ]] && pass_test || fail_test "no jarvos:summary in:$missing"
```

- [ ] **Step 2: Run it, see exactly which commands fail, add the headers**

Each gets `# jarvos:summary=`, and `# jarvos:args=` plus `# jarvos:examples=` where the command takes arguments. Take the wording from each command's existing header comment — do not invent new descriptions, and do not reword what is already accurate.

- [ ] **Step 3: Run the full suite and commit**

```bash
git add bin tests/jarvos-agent.test.sh
git commit -m "refactor(runtime): give every jarvos command a self-describing header

summary/args/examples on all 19 commands, taken from their existing header
comments rather than reworded. Nothing consumes this yet — it is what lets
a menu or cheatsheet be generated later instead of hand-maintained, and
retrofitting 19 is cheaper than retrofitting 40."
```

---

# Track B — Caelestia removal, part 2

Independent of Track A. Same TDD shape as Part 1: pure logic into a `.js` library with `qmltestrunner` tests, thin QML wiring on top. Read `utils/calc.js` and `utils/Calc.qml` first — they are the best worked example in the repo.

Each task ends with a deploy and restart:

```bash
cp -rf config/.config/quickshell/jarvos/. ~/.config/quickshell/jarvos/
systemctl --user restart quickshell-jarvos.service
```

If the shell does not come back, revert, redeploy, restart, report. Do not iterate on a broken desktop.

## Task 6: `CircularBuffer`

**Files:** Create `utils/circularbuffer.js`, `utils/CircularBuffer.qml`, `tests/qml/tst_circularbuffer.qml`. Modify `services/NetworkUsage.qml`.

**Surface:** `capacity` (set), `push(value)`, `maximum`, `count`, and a `valuesChanged` signal. Two instantiations in `NetworkUsage.qml` (lines ~145, ~150) and two property declarations (~26-27).

**The trap:** `maximum`, `count` and `valuesChanged` are read **cross-file** from `modules/dashboard/Performance.qml` and `modules/bar/popouts/NetworkSpeed.qml` via `NetworkUsage.downloadBuffer.*`, including a `Connections { target: ...; function onValuesChanged() }`. Those names are a contract. Grep every consumer before choosing them.

- [ ] **Step 1: Grep the real consumers**

Run: `grep -rn 'downloadBuffer\|uploadBuffer' config/.config/quickshell/jarvos --include=*.qml`

Report what you find. Any member reachable from another file must keep its name and its signal.

- [ ] **Step 2: Write failing tests for the ring buffer**

Cover: eviction past capacity; `maximum` over the retained window only, not all values ever pushed; `count` before the buffer fills; `maximum` of an empty buffer; and that pushing a value which is not the largest still leaves `maximum` correct after eviction removes the old largest.

- [ ] **Step 3: Run, see them fail, write `circularbuffer.js`**

- [ ] **Step 4: Write `CircularBuffer.qml`**, a `QtObject` wrapping the JS with a `valuesChanged` signal emitted on push.

- [ ] **Step 5: Migrate `NetworkUsage.qml`**, drop `import Caelestia.Internal` if nothing else in the file needs it.

- [ ] **Step 6: Verify the graphs still move**

Deploy, restart, then watch the network speed chip and the dashboard performance graphs. Both read this buffer — a broken `valuesChanged` shows as a frozen sparkline, not an error.

- [ ] **Step 7: Commit**

```bash
git add config/.config/quickshell/jarvos tests/qml
git commit -m "refactor(shell): replace CircularBuffer with our own ring buffer

maximum, count and valuesChanged are read cross-file by the network chip
and the dashboard graphs, so those names are a contract rather than an
implementation detail. maximum is over the retained window, which is what
the sparklines scale against."
```

---

## Task 7: `FileSystemModel` and `FileSystemEntry`

**Files:** Create `utils/filesystem.js`, `utils/FileSystemModel.qml`, `tests/qml/tst_filesystem.qml`. Modify `components/filedialog/FolderContents.qml`, `modules/utilities/cards/RecordingList.qml`, `services/Wallpapers.qml`, `modules/launcher/items/WallpaperItem.qml`.

**Surface:** Model — `path`, `recursive`, `filter` with a static `FileSystemModel.Images`, `nameFilters`, `sortReverse`, and an `onPathChanged` handler. Entry — `path`, `name`, `isDir`, `baseName`, `relativePath`.

**The trap:** `Wallpapers.qml` sets `recursive: true` and `filter: FileSystemModel.Images`. A static enum on a QML type needs deliberate handling — decide how `Images` is expressed and report it before migrating the call sites.

- [ ] **Step 1: Grep every property actually set across the three instantiations**, and report it. The spec's list is from recon; confirm it.

- [ ] **Step 2: Write failing tests** for the pure logic: name filtering, image-extension matching, sort order and its reversal, and `baseName`/`relativePath` derivation. Include a filename with a dot in it and one with no extension.

- [ ] **Step 3: Run, see them fail, write `filesystem.js`**

- [ ] **Step 4: Write `FileSystemModel.qml`** over `Quickshell.Io` — a `Process` listing or `FolderListModel` where recursion is not needed. Recursion is required by `Wallpapers.qml`.

- [ ] **Step 5: Migrate the four call sites**

- [ ] **Step 6: Verify each surface**: the wallpaper grid populates and wallpapers apply; the recordings list shows recordings with correct names; the file dialog browses and enters directories.

- [ ] **Step 7: Commit**

---

## Task 8: `ServiceRef` — decide with evidence

**Files:** Modify `modules/background/Visualiser.qml`, `modules/dashboard/Media.qml`, `modules/dashboard/dash/Media.qml`. Possibly create `components/misc/ServiceRef.qml`.

`service` is set at four sites and **never read**. It is a refcount that keeps a service alive while a consumer is mounted.

- [ ] **Step 1: Establish what it actually does, then decide**

Determine whether anything depends on that lifetime behaviour — specifically whether `Audio.cava` and `Audio.beatTracker` start and stop based on it.

**Report the finding and the decision before implementing.** Reimplement it if the lifetime matters; delete it if nothing observes the difference. Deleting something whose only job is a side effect you have not verified is how a process ends up running forever.

- [ ] **Step 2: Implement whichever you chose**

- [ ] **Step 3: Verify the visualiser and media widgets still work**, and that no audio process is left running when nothing is watching. Check with `pgrep`.

- [ ] **Step 4: Commit**, recording the decision and its evidence in the body.

---

## Task 9: The toast system

**Files:** Create `services/Toaster.qml`, `components/misc/Toast.qml`, `utils/toast.js`, `tests/qml/tst_toast.qml`. Modify the 12 files calling `Toaster.toast`, plus `modules/utilities/toasts/{Toasts,ToastItem}.qml`.

The widest change in the removal — 12 files, ~30 call sites — but shallow.

**Surface:** `Toaster.toast(title, message, icon, type?)` and `Toaster.toasts`. `Toast` carries `type`, `icon`, `title`, `message`, `closed`, `close()`, `lock(target)`, `unlock(target)`, and the enum values `Success`, `Warning`, `Error`, `Info`.

**The trap:** `lock`/`unlock` exist so a hovered toast does not expire. That behaviour must survive, and it is invisible in a screenshot — a toast that vanishes while you read it is the regression.

- [ ] **Step 1: Grep every `Toaster.toast` call and record its argument shape.** Some pass an icon, some a type, some both. Report the variants before designing the signature.

- [ ] **Step 2: Write failing tests** for the queue logic in `toast.js`: adding, closing, that a locked toast is not expired, that unlocking lets it expire again, and that closing one leaves the others.

- [ ] **Step 3: Run, see them fail, write `toast.js`**

- [ ] **Step 4: Write `Toast.qml`** with the enum, and `Toaster.qml` as the singleton.

Keep `Toast.Error` and friends resolving unchanged at the call sites — a QML `enum` in the component gives that.

- [ ] **Step 5: Migrate all 12 call sites plus the two toast UI files**

- [ ] **Step 6: Verify for real, including the hover case**

Trigger a toast (toggling game mode or a VPN is easy), and **hover it** — it must not expire while hovered, and must expire after you move away. Check each of the four types renders with its own colour.

- [ ] **Step 7: Commit**

```bash
git add config/.config/quickshell/jarvos tests/qml
git commit -m "refactor(shell): replace the Caelestia toast system

12 files and ~30 call sites, but a shallow surface: one method, a list, and
a Toast with a lifecycle. The enum stays a QML enum so Toast.Error keeps
resolving unchanged at every call site.

lock/unlock is why a hovered toast does not expire. It is invisible in a
screenshot and the regression it prevents — a toast vanishing mid-read —
was verified by hand."
```

---

## Done when

- `Super+A` still opens Claude Desktop, unchanged.
- `jarvos-default-agent codex` then `Super+A` opens Codex in a terminal.
- A failed `jarvos-update` offers a diagnosis and does not run it.
- Every `bin/jarvos-*` has a `jarvos:summary`.
- `grep -rn 'CircularBuffer\|FileSystemModel\|FileSystemEntry\|ServiceRef\|Toaster\|Toast\b' config/.config/quickshell/jarvos/` returns only our own types.
- The shell launches with no new QML errors; sparklines move, wallpapers apply, recordings list, toasts appear and survive a hover.
- `tests/run-all.sh` exits 0 with every prior total intact.

## Handoff

For the next plan (removal Part 3 + the usage layer):
- what Task 8 decided about `ServiceRef`, and the evidence
- the `Toaster.toast` argument variants found in Task 9 Step 1
- whether `modules/bar/` is settled enough for the usage chip to land
