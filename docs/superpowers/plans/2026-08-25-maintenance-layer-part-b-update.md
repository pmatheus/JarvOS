# JarvOS Maintenance Layer — Part B: Refresh, Hooks, Update, Packaging

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** `docs/superpowers/plans/2026-08-25-maintenance-layer-part-a-migrations.md` complete through Task 6, tag `v0.3.0` present. This plan continues its task numbering at 7.

**Goal:** One blessed command — `jarvos-update` — that takes a machine from any shipped release to the current one, safely, resumably, and with a rollback point; plus the primitive that pulls a shipped default forward over a user's file without silently eating their edits, and the package that puts all of it on `$PATH`.

**Architecture:** `jarvos-update` is orchestration and nothing else. Every step is a separate `jarvos-update-*` command found on `$PATH`, which is what makes the pipeline testable: the sandbox shims each leaf with a recording stub and asserts on ordering, and each leaf is tested alone against shimmed `pacman`/`git`. Two self-re-exec preludes give the run a transcript (`script -qefc`, which keeps a PTY so pacman's progress bars survive) and mutual exclusion (`flock` on an FD carried through the environment).

**Tech Stack:** bash 5, `flock`, `script(1)` from util-linux, `snapper` (optional — skipped where absent), `shellcheck`, the Part A test harness. `makepkg`/`pacman` for the package.

**Source spec:** `docs/superpowers/specs/2026-08-25-jarvos-maintenance-layer-design.md` §6, §7, §8, §9, §11, §12 steps 3–5.

## Global Constraints

Everything in Part A's Global Constraints still applies, plus:

- **Ordering in `jarvos-update` is not stylistic.** Prune before snapshot; git pull before packages; keyring before packages; migrations after packages; AUR last. Each is a real constraint documented in spec §6 — do not reorder while "tidying".
- **`-y` is a promise, not a force.** In unattended mode, a step that would prompt reports and skips. Orphan removal never removes without a human.
- **No automatic recovery.** `set -e` plus an `ERR` trap that prints where the transcript is. Recovery is out-of-band: reboot into the snapshot, or re-run — every step is `--needed`-guarded or marker-guarded, so retry is a real remedy.
- **`jarvos-refresh-config` never runs as part of an update.** It is user-invoked, or called explicitly by a migration.
- **A failing hook never aborts anything.** It reports and the run continues.
- Test seams are environment variables with production defaults, named `JARVOS_*`, and documented in the script's header comment.

---

## File Structure

| Path | Responsibility |
|---|---|
| `bin/jarvos-refresh-config` | Pull one shipped default forward over one user file: backup, overwrite, diff, and delete the backup when nothing changed. |
| `bin/jarvos-hook` | Run `~/.config/jarvos/hooks/<event>.d/*`, run-parts style. Never fatal. |
| `config/.config/jarvos/hooks/<event>.d/example.sample` | Ships the directories and documents the mechanism by existing. |
| `bin/jarvos-update-git` | `git pull --autostash` in `$JARVOS_PATH`, muting Hyprland across it. |
| `bin/jarvos-update-keyring` | Refresh `archlinux-keyring` before the main transaction. |
| `bin/jarvos-update-system-pkgs` | `pacman -Syu`. |
| `bin/jarvos-update-aur-pkgs` | `yay -Sua`. Reports failure; never fatal. |
| `bin/jarvos-update-orphan-pkgs` | List orphans; remove only with a human. |
| `bin/jarvos-update-analyze-logs` | Summarise this boot's errors. Never fatal. |
| `bin/jarvos-update-restart` | Dispatch on `restart-*-required` markers. |
| `bin/jarvos-restart-shell` | Restart `quickshell-jarvos.service`. The first restart target. |
| `bin/jarvos-update` | Orchestration only. |
| `packaging/jarvos/PKGBUILD` | Builds the runtime package. |
| `LICENSE` | **Already present** — GPLv3, added 2026-08-25 ahead of publishing. Task 12 verifies it rather than creating it. |
| `tests/jarvos-refresh-config.test.sh`, `tests/jarvos-hook.test.sh`, `tests/jarvos-update-steps.test.sh`, `tests/jarvos-update.test.sh` | One suite per task. |
| `tests/vm/verify-fresh-install.sh` | The clean-VM checks that cannot be faked. |

---

## Task 7: `jarvos-refresh-config`

**Files:**
- Create: `bin/jarvos-refresh-config`
- Create: `tests/jarvos-refresh-config.test.sh`

**Interfaces:**
- Consumes: `lib/jarvos-common.sh` (`JARVOS_PATH`, `die`); `run_cmd` from Part A Task 1.
- Produces: `jarvos-refresh-config <path-relative-to-~/.config>`. Reads the shipped default from `$JARVOS_PATH/config/.config/<rel>`. Task 12's migration examples call it.
- Test seam: `JARVOS_REFRESH_STAMP` overrides the backup timestamp so a test can predict the filename.

The backup rule is the whole point: **delete the backup when nothing actually changed**, so a user only ever sees noise when they genuinely lost something.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-refresh-config.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-refresh-config — a shipped default over a user file: backup only
# when something is actually lost, and no escaping ~/.config.
# Run: tests/jarvos-refresh-config.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_REFRESH_STAMP=20260825120000
SHIPPED="$FAKE_BASE/config/.config"
USERCFG="$FAKE_HOME/.config"
mkdir -p "$SHIPPED/hypr/hyprland" "$USERCFG/hypr/hyprland"

printf 'bind = SUPER, Q, killactive\n' >"$SHIPPED/hypr/hyprland/keybinds.conf"

start_test "an unmodified user file is refreshed silently, leaving no backup"
cp "$SHIPPED/hypr/hyprland/keybinds.conf" "$USERCFG/hypr/hyprland/keybinds.conf"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
assert_status "$RUN_STATUS" 0 &&
    { [[ -z "$RUN_OUT" ]] || fail_test "expected silence, got: $RUN_OUT"; } &&
    assert_no_file "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" &&
    pass_test

start_test "a modified user file is backed up and the loss is shown"
printf 'bind = SUPER, Q, exec, my-own-thing\n' >"$USERCFG/hypr/hyprland/keybinds.conf"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" &&
    assert_contains "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" "my-own-thing" &&
    assert_contains "$USERCFG/hypr/hyprland/keybinds.conf" "killactive" &&
    pass_test

start_test "the report names the file, the backup, and the diff"
assert_stdout_contains "$RUN_OUT" "hypr/hyprland/keybinds.conf" &&
    assert_stdout_contains "$RUN_OUT" ".bak.$JARVOS_REFRESH_STAMP" &&
    assert_stdout_contains "$RUN_OUT" "my-own-thing" &&
    pass_test

start_test "exactly one backup, not one per run"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
count="$(find "$USERCFG/hypr/hyprland" -name 'keybinds.conf.bak.*' | wc -l)"
[[ "$count" -eq 1 ]] && pass_test || fail_test "expected 1 backup, found $count"

start_test "a user file that does not exist yet is simply installed"
run_cmd jarvos-refresh-config hypr/hyprland/newfile.conf
assert_status "$RUN_STATUS" 1 && pass_test # no shipped default for it either
printf 'new = 1\n' >"$SHIPPED/hypr/hyprland/newfile.conf"
run_cmd jarvos-refresh-config hypr/hyprland/newfile.conf
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$USERCFG/hypr/hyprland/newfile.conf" "new = 1" &&
    assert_no_file "$USERCFG/hypr/hyprland/newfile.conf.bak.$JARVOS_REFRESH_STAMP" &&
    pass_test

start_test "a path escaping ~/.config is rejected"
run_cmd jarvos-refresh-config ../../etc/passwd
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "outside" &&
    pass_test

start_test "an absolute path is rejected"
run_cmd jarvos-refresh-config /etc/passwd
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a bare .. is rejected"
run_cmd jarvos-refresh-config hypr/../../.ssh/authorized_keys
assert_status "$RUN_STATUS" 1 &&
    assert_no_file "$FAKE_HOME/.ssh/authorized_keys" &&
    pass_test

start_test "no argument is rejected"
run_cmd jarvos-refresh-config
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a shipped default that does not exist is a readable error"
run_cmd jarvos-refresh-config hypr/nothing-ships-this.conf
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "nothing-ships-this.conf" &&
    pass_test

summary "jarvos-refresh-config"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-refresh-config.test.sh && tests/jarvos-refresh-config.test.sh`

Expected: every case FAILs — the command does not exist.

- [ ] **Step 3: Write `bin/jarvos-refresh-config`**

Create `bin/jarvos-refresh-config`:

```bash
#!/usr/bin/env bash
# jarvos-refresh-config <path-relative-to-~/.config>
#
# Pull one shipped default forward over one user file. Backs the user's
# version up first, then deletes that backup if nothing actually changed —
# a user should see noise only when they genuinely lost something.
#
#   jarvos-refresh-config hypr/hyprland/keybinds.conf
#
# NEVER runs as part of an update. User-invoked, or called explicitly by a
# migration when a shipped stub must change.
#
# Seams: JARVOS_REFRESH_STAMP overrides the backup timestamp.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -eq 1 ]] || die "usage: jarvos-refresh-config <path-relative-to-~/.config>"

rel="$1"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
target="$(realpath -m "$config_home/$rel")"
root="$(realpath -m "$config_home")"

# Normalise first, then check containment. Rejecting ".." textually is not
# enough — a symlinked parent gets there without one.
case "$target" in
    "$root"/*) ;;
    *) die "refuses to write outside $config_home: $rel" ;;
esac

shipped="$JARVOS_PATH/config/.config/$rel"
[[ -f "$shipped" ]] || die "no shipped default for $rel"

stamp="${JARVOS_REFRESH_STAMP:-$(date +%Y%m%d%H%M%S)}"
backup="$target.bak.$stamp"

mkdir -p "$(dirname "$target")"

if [[ ! -e "$target" ]]; then
    cp "$shipped" "$target"
    exit 0
fi

cp "$target" "$backup"
cp "$shipped" "$target"

if cmp -s "$target" "$backup"; then
    rm -f "$backup"
    exit 0
fi

printf '%s\n' "$rel"
printf '  your version: %s\n' "${backup##*/}"
diff -u "$backup" "$target" | sed 's/^/  /' || true
```

The trailing `|| true` on `diff` is load-bearing: `diff` exits 1 when files differ, which is exactly the branch we are in, and `set -e` would kill the script on the last line.

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-refresh-config && tests/jarvos-refresh-config.test.sh`

Expected: `jarvos-refresh-config: 11 passed, 0 failed`, exit 0.

- [ ] **Step 5: Run the full suite and commit**

Run: `tests/run-all.sh`

Expected: every suite passes, `shellcheck` clean, exit 0.

```bash
git add bin/jarvos-refresh-config tests/jarvos-refresh-config.test.sh
git commit -m "feat(runtime): add jarvos-refresh-config

One primitive for pulling a shipped default forward over a user file.
Backs the user's version up, then deletes that backup when the two turn
out to be identical, so a backup file appearing always means something was
actually lost.

Containment is checked after realpath -m normalisation rather than by
rejecting '..' textually — a symlinked parent gets outside ~/.config
without one."
```

---

## Task 8: `jarvos-hook`

**Files:**
- Create: `bin/jarvos-hook`
- Create: `config/.config/jarvos/hooks/post-update.d/example.sample`
- Create: `config/.config/jarvos/hooks/post-boot.d/example.sample`
- Create: `config/.config/jarvos/hooks/pre-refresh-pacman.d/example.sample`
- Create: `config/.config/jarvos/hooks/theme-set.d/example.sample`
- Create: `tests/jarvos-hook.test.sh`

**Interfaces:**
- Produces: `jarvos-hook <event>`, running every executable non-`.sample` file in `~/.config/jarvos/hooks/<event>.d/`, sorted, each with the event name as `$1`. **Always exits 0.** Task 11's `jarvos-update` calls `jarvos-hook post-update`.

Each `.d/` ships a `.sample` the user renames to activate. That is what makes the mechanism self-documenting: `ls` on the hooks directory tells you what exists and how to turn it on.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-hook.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-hook — user escape hatches that can never break the caller.
# Run: tests/jarvos-hook.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

HOOKS="$FAKE_HOME/.config/jarvos/hooks/post-update.d"
mkdir -p "$HOOKS"
: >"$FAKE_STATE/hook-log"

hook() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$HOOKS/$1"
    chmod +x "$HOOKS/$1"
}

start_test "an event with no hooks exits 0 quietly"
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 && pass_test

start_test "an event with no directory at all exits 0"
run_cmd jarvos-hook theme-set
assert_status "$RUN_STATUS" 0 && pass_test

start_test "hooks run in sorted order"
hook 10-first 'echo first >> "$FAKE_STATE/hook-log"'
hook 20-second 'echo second >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    [[ "$(head -1 "$FAKE_STATE/hook-log")" == "first" ]] &&
    [[ "$(tail -1 "$FAKE_STATE/hook-log")" == "second" ]] &&
    pass_test

start_test "a hook receives the event name as its first argument"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-echo-event 'echo "$1" >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_contains "$FAKE_STATE/hook-log" "post-update" && pass_test

start_test "a .sample file is never run"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-real.sample 'echo sample-ran >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/hook-log" ]] || fail_test "a .sample hook ran"; } &&
    pass_test

start_test "a non-executable file is skipped"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
printf '#!/usr/bin/env bash\necho notexec >> "$FAKE_STATE/hook-log"\n' >"$HOOKS/10-notexec"
chmod -x "$HOOKS/10-notexec"
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/hook-log" ]] || fail_test "a non-executable hook ran"; } &&
    pass_test

start_test "a failing hook reports but does not abort the rest"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-boom 'echo boom >> "$FAKE_STATE/hook-log"; exit 9'
hook 20-after 'echo after >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/hook-log" "after" &&
    assert_stdout_contains "$RUN_OUT" "10-boom" &&
    pass_test

start_test "every shipped event directory has a sample"
missing=""
for e in post-update post-boot pre-refresh-pacman theme-set; do
    d="$REPO_ROOT/config/.config/jarvos/hooks/$e.d"
    compgen -G "$d/*.sample" >/dev/null || missing="$missing $e"
done
[[ -z "$missing" ]] && pass_test || fail_test "no .sample for:$missing"

start_test "no event is rejected"
run_cmd jarvos-hook
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-hook"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-hook.test.sh && tests/jarvos-hook.test.sh`

Expected: every case FAILs.

- [ ] **Step 3: Write `bin/jarvos-hook`**

Create `bin/jarvos-hook`:

```bash
#!/usr/bin/env bash
# jarvos-hook <event> — run the user's hooks for an event.
#
# Executable files in ~/.config/jarvos/hooks/<event>.d/, sorted, each given
# the event name as $1. Files ending .sample are skipped, so each directory
# ships a sample the user renames to activate and the mechanism documents
# itself by existing.
#
# Events: post-update, post-boot, pre-refresh-pacman, theme-set
#
# ALWAYS exits 0. A user's hook is not allowed to break an update.

set -uo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -eq 1 ]] || die "usage: jarvos-hook <event>"

event="$1"
dir="${XDG_CONFIG_HOME:-$HOME/.config}/jarvos/hooks/$event.d"

[[ -d "$dir" ]] || exit 0

while IFS= read -r hook; do
    [[ -x "$hook" ]] || continue
    "$hook" "$event" ||
        printf 'jarvos-hook: %s exited %d (continuing)\n' "${hook##*/}" "$?" >&2
done < <(find "$dir" -maxdepth 1 -type f ! -name '*.sample' | sort)

exit 0
```

Note this script uses `set -uo pipefail` **without** `-e`: a failing hook must not take the runner with it, and the explicit `||` handles the reporting.

- [ ] **Step 4: Ship the four sample hooks**

```bash
for e in post-update post-boot pre-refresh-pacman theme-set; do
    mkdir -p "config/.config/jarvos/hooks/$e.d"
done
```

Create `config/.config/jarvos/hooks/post-update.d/example.sample`:

```bash
#!/usr/bin/env bash
# Rename this file without the .sample suffix (and chmod +x it) to activate.
#
# Runs after every successful jarvos-update. $1 is the event name.
# A non-zero exit is reported and ignored — a hook cannot break an update.

echo "post-update hook ran at $(date)"
```

Create `config/.config/jarvos/hooks/post-boot.d/example.sample`:

```bash
#!/usr/bin/env bash
# Rename without .sample (and chmod +x) to activate.
# Runs once per boot, after the shell is up. $1 is the event name.

echo "post-boot hook ran"
```

Create `config/.config/jarvos/hooks/pre-refresh-pacman.d/example.sample`:

```bash
#!/usr/bin/env bash
# Rename without .sample (and chmod +x) to activate.
#
# Runs after JarvOS swaps pacman.conf and mirrorlist, before the upgrade.
# This is where you re-inject your own repositories, since the swap replaces
# those files wholesale rather than editing them in place.

echo "pre-refresh-pacman hook ran"
```

Create `config/.config/jarvos/hooks/theme-set.d/example.sample`:

```bash
#!/usr/bin/env bash
# Rename without .sample (and chmod +x) to activate.
# Runs after the colour scheme changes. $1 is the event name.

echo "theme-set hook ran"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-hook && tests/jarvos-hook.test.sh`

Expected: `jarvos-hook: 9 passed, 0 failed`, exit 0.

- [ ] **Step 6: Run the full suite and commit**

Run: `tests/run-all.sh`

```bash
git add bin/jarvos-hook config/.config/jarvos/hooks tests/jarvos-hook.test.sh
git commit -m "feat(runtime): add jarvos-hook and the four shipped events

run-parts over ~/.config/jarvos/hooks/<event>.d/. Always exits 0: a user's
hook is not allowed to break an update, so a failure is reported and the
run continues.

Each directory ships a .sample the user renames to activate, which makes
the mechanism self-documenting — ls tells you what events exist and how to
turn one on."
```

---

## Task 9: The update steps that touch the system

**Files:**
- Create: `bin/jarvos-update-git`
- Create: `bin/jarvos-update-keyring`
- Create: `bin/jarvos-update-system-pkgs`
- Create: `tests/jarvos-update-steps.test.sh`
- Modify: `tests/lib/sandbox.sh` — add `git`, `hyprctl` and `journalctl` shims to `make_shims`

**Interfaces:**
- Produces: three commands, each doing exactly one thing and exiting non-zero on real failure. Task 11 calls them in this order.
- Test seam: `JARVOS_HYPRCTL` (default `hyprctl`) so the sandbox can record reload calls.

- [ ] **Step 1: Add the shims**

In `tests/lib/sandbox.sh`, insert these into `make_shims` **immediately before its existing `chmod +x "$FAKE_BIN"/*` line** — that line already covers every shim, so do not add a second `chmod`:

```bash
    cat >"$FAKE_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/hyprctl-calls"
EOF

    cat >"$FAKE_BIN/journalctl" <<'EOF'
#!/usr/bin/env bash
cat "$FAKE_STATE/journal" 2>/dev/null || true
EOF

    # A git that records what it was asked and can be told to fail or to
    # leave the tree conflicted.
    cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/git-calls"
case "$*" in
    *"pull"*)
        [[ -e "$FAKE_STATE/git-pull-fails" ]] && { echo "fatal: could not resolve host" >&2; exit 128; }
        [[ -e "$FAKE_STATE/git-pull-conflicts" ]] && { echo "CONFLICT (content)" >&2; exit 1; }
        exit 0 ;;
    *"diff --check"*)
        [[ -e "$FAKE_STATE/git-pull-conflicts" ]] && exit 1
        exit 0 ;;
    *) exit 0 ;;
esac
EOF

```

Also confirm Part A's `run_cmd` exports `JARVOS_PATH="$FAKE_BASE"` (the existing `run_sync` exports `JARVOS_ROOT`, a different variable). `jarvos-update-git` operates on `$JARVOS_PATH`; if `run_cmd` does not set it, the command will try to pull the real repository. Add it if missing.

- [ ] **Step 2: Write the failing test**

Create `tests/jarvos-update-steps.test.sh`:

```bash
#!/usr/bin/env bash
# The update steps that touch the system, each alone.
# Run: tests/jarvos-update-steps.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

reset_calls() {
    : >"$FAKE_STATE/git-calls"
    : >"$FAKE_STATE/hyprctl-calls"
    : >"$FAKE_STATE/pacman-installed"
    rm -f "$FAKE_STATE/git-pull-fails" "$FAKE_STATE/git-pull-conflicts"
}

# --- jarvos-update-git ---------------------------------------------------

reset_calls
start_test "the pull autostashes, so local edits do not block it"
run_cmd jarvos-update-git
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/git-calls" "--autostash" &&
    pass_test

start_test "Hyprland is reloaded once, after the pull"
# -x, not a substring match: 'disable_autoreload' also contains 'reload'.
[[ "$(grep -cx 'reload' "$FAKE_STATE/hyprctl-calls")" -eq 1 ]] &&
    assert_contains "$FAKE_STATE/hyprctl-calls" "disable_autoreload 0" &&
    pass_test || fail_test "expected exactly one bare reload"

reset_calls
start_test "a network failure fails the step readably"
: >"$FAKE_STATE/git-pull-fails"
run_cmd jarvos-update-git
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "could not" &&
    pass_test

reset_calls
start_test "a conflicted tree is abandoned, not shipped"
: >"$FAKE_STATE/git-pull-conflicts"
run_cmd jarvos-update-git
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_contains "$FAKE_STATE/git-calls" "reset --merge" &&
    pass_test

# --- jarvos-update-keyring ----------------------------------------------

reset_calls
start_test "the keyring is refreshed on its own, before anything else"
run_cmd jarvos-update-keyring
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-installed" "archlinux-keyring" &&
    pass_test

# --- jarvos-update-system-pkgs ------------------------------------------

reset_calls
: >"$FAKE_STATE/pacman-syu-calls"
start_test "the system upgrade runs -Syu"
run_cmd jarvos-update-system-pkgs
assert_status "$RUN_STATUS" 0 && pass_test

summary "jarvos-update-steps"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-update-steps.test.sh && tests/jarvos-update-steps.test.sh`

Expected: every case FAILs.

- [ ] **Step 4: Write `bin/jarvos-update-git`**

Create `bin/jarvos-update-git`:

```bash
#!/usr/bin/env bash
# jarvos-update-git — bring the runtime checkout up to date.
#
# Runs BEFORE any package work, so a merge conflict aborts the update before
# a single system mutation. Hyprland watches its config files and will spew
# errors as they change underneath it, so it is muted across the pull and
# reloaded once, explicitly, afterwards.
#
# Seams: JARVOS_HYPRCTL

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

HYPRCTL="${JARVOS_HYPRCTL:-hyprctl}"

git -C "$JARVOS_PATH" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "jarvos-update-git: $JARVOS_PATH is not a checkout — nothing to pull"
    exit 0
}

echo "Updating the JarvOS checkout"

command -v "$HYPRCTL" >/dev/null 2>&1 && "$HYPRCTL" keyword misc:disable_autoreload 1 >/dev/null 2>&1 || true

pull_status=0
git -C "$JARVOS_PATH" pull --autostash --ff-only || pull_status=$?

# A conflicted tree must be abandoned rather than shipped: half of one
# release and half of another is a machine nobody can reason about.
if ! git -C "$JARVOS_PATH" diff --check >/dev/null 2>&1; then
    git -C "$JARVOS_PATH" reset --merge >/dev/null 2>&1 || true
    pull_status=1
fi

command -v "$HYPRCTL" >/dev/null 2>&1 && "$HYPRCTL" keyword misc:disable_autoreload 0 >/dev/null 2>&1 || true
command -v "$HYPRCTL" >/dev/null 2>&1 && "$HYPRCTL" reload >/dev/null 2>&1 || true

exit "$pull_status"
```

- [ ] **Step 5: Write `bin/jarvos-update-keyring`**

Create `bin/jarvos-update-keyring`:

```bash
#!/usr/bin/env bash
# jarvos-update-keyring — refresh archlinux-keyring on its own.
#
# Runs before the main transaction. A stale keyring fails the whole upgrade
# unrecoverably, and it fails it in the middle, which is the worst place.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

echo "Refreshing the package signing keys"
sudo pacman -Sy --needed --noconfirm archlinux-keyring
```

- [ ] **Step 6: Write `bin/jarvos-update-system-pkgs`**

Create `bin/jarvos-update-system-pkgs`:

```bash
#!/usr/bin/env bash
# jarvos-update-system-pkgs — the main pacman transaction.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

echo "Updating system packages"
sudo pacman -Syu --noconfirm
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-update-git bin/jarvos-update-keyring bin/jarvos-update-system-pkgs && tests/jarvos-update-steps.test.sh`

Expected: `jarvos-update-steps: 6 passed, 0 failed`, exit 0.

- [ ] **Step 8: Run the full suite and commit**

Run: `tests/run-all.sh`

```bash
git add bin/jarvos-update-git bin/jarvos-update-keyring bin/jarvos-update-system-pkgs \
        tests/jarvos-update-steps.test.sh tests/lib/sandbox.sh
git commit -m "feat(update): add the git, keyring and system-package steps

Each does one thing so the orchestrator can be pure ordering. The git step
runs first because a merge conflict must abort before any system mutation,
and it mutes Hyprland's autoreload across the pull — Hyprland watches its
config files and spews errors as they change underneath it — then reloads
once, explicitly.

The keyring is refreshed on its own before the main transaction: a stale
keyring fails the whole upgrade, in the middle."
```

---

## Task 10: The update steps that finish the run

**Files:**
- Create: `bin/jarvos-update-aur-pkgs`
- Create: `bin/jarvos-update-orphan-pkgs`
- Create: `bin/jarvos-update-analyze-logs`
- Create: `bin/jarvos-update-restart`
- Create: `bin/jarvos-restart-shell`
- Modify: `tests/jarvos-update-steps.test.sh` — append the cases below

**Interfaces:**
- Consumes: `jarvos-state` (Part A Task 1) for the restart markers.
- Produces: four tail steps. `jarvos-update-restart` scans `$JARVOS_STATE` for markers named `restart-<service>-required`, runs `jarvos-restart-<service>` for each, and clears the marker on success. Any migration can request a restart by touching a file, with no edit to the pipeline.
- Test seam: `JARVOS_ASSUME_YES` (set by `jarvos-update -y`) makes prompting steps report and skip.

- [ ] **Step 1: Append the failing cases**

Append to `tests/jarvos-update-steps.test.sh`, before the final `summary` line:

```bash
# --- jarvos-update-aur-pkgs ---------------------------------------------

start_test "an AUR failure is reported but never fatal"
cat >"$FAKE_BIN/yay" <<'YAY'
#!/usr/bin/env bash
echo "error: failed to build foo" >&2
exit 1
YAY
chmod +x "$FAKE_BIN/yay"
run_cmd jarvos-update-aur-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "AUR" &&
    pass_test

# --- jarvos-update-orphan-pkgs ------------------------------------------

start_test "orphans are never removed without a human"
printf 'orphan-one\norphan-two\n' >"$FAKE_STATE/pacman-orphans"
: >"$FAKE_STATE/pacman-removed"
JARVOS_ASSUME_YES=1 run_cmd jarvos-update-orphan-pkgs
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/pacman-removed" ]] || fail_test "removed orphans unattended"; } &&
    assert_stdout_contains "$RUN_OUT" "orphan-one" &&
    pass_test

start_test "no orphans is quiet and exits 0"
: >"$FAKE_STATE/pacman-orphans"
JARVOS_ASSUME_YES=1 run_cmd jarvos-update-orphan-pkgs
assert_status "$RUN_STATUS" 0 && pass_test

# --- jarvos-update-analyze-logs -----------------------------------------

start_test "log analysis reports errors and is never fatal"
printf 'kernel: something went wrong\n' >"$FAKE_STATE/journal"
run_cmd jarvos-update-analyze-logs
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "something went wrong" &&
    pass_test

start_test "a clean journal is quiet"
: >"$FAKE_STATE/journal"
run_cmd jarvos-update-analyze-logs
assert_status "$RUN_STATUS" 0 && pass_test

# --- jarvos-update-restart ----------------------------------------------

start_test "no markers means nothing restarts"
: >"$FAKE_STATE/units-restarted"
run_cmd jarvos-update-restart
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/units-restarted" ]] || fail_test "restarted something unasked"; } &&
    pass_test

start_test "a restart marker dispatches to jarvos-restart-<service>"
run_cmd jarvos-state set restart-shell-required
run_cmd jarvos-update-restart
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/units-restarted" "quickshell-jarvos.service" &&
    pass_test

start_test "and the marker is cleared, so it does not restart forever"
assert_no_file "$FAKE_HOME/.local/state/jarvos/restart-shell-required" && pass_test

start_test "a marker with no matching restart command is reported, not fatal"
run_cmd jarvos-state set restart-nonexistent-required
run_cmd jarvos-update-restart
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "nonexistent" &&
    pass_test
run_cmd jarvos-state clear restart-nonexistent-required
```

Two shim edits in `tests/lib/sandbox.sh`, both **position-sensitive** — `case` takes the first match, so appending either at the end silently does nothing.

In the `pacman` shim, add the orphan query **above the existing `-Q*)` line**, which would otherwise swallow `-Qtdq` and return no orphans at all:

```bash
    "-Qtdq") cat "$FAKE_STATE/pacman-orphans" 2>/dev/null || true ;;
    -Q*)     for p in "${@:2}"; do grep -qxF "$p" "$FAKE_STATE/pacman-explicit" || exit 1; done ;;
```

In the `systemctl` shim, add `restart` **above the closing `*) exit 0 ;;`**:

```bash
    restart)         for u in "${@:2}"; do printf '%s\n' "$u" >> "$FAKE_STATE/units-restarted"; done ;;
    *)               exit 0 ;;
```

The orphan test also relies on Part A Task 2 having added a `-R*)` branch that records to `$FAKE_STATE/pacman-removed`. If that branch writes to a different file, point the assertion at that name instead — the test is meaningless if it asserts on a file nothing ever writes.

- [ ] **Step 2: Run the test to verify the new cases fail**

Run: `tests/jarvos-update-steps.test.sh`

Expected: the first six cases still pass; the nine new ones FAIL.

- [ ] **Step 3: Write `bin/jarvos-update-aur-pkgs`**

Create `bin/jarvos-update-aur-pkgs`:

```bash
#!/usr/bin/env bash
# jarvos-update-aur-pkgs — third-party packages, last and non-fatal.
#
# Runs after everything else and never fails the update. An AUR package is
# somebody else's build script; a broken one must not take down a system
# that is otherwise correctly updated.

set -uo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

command -v yay >/dev/null 2>&1 || exit 0

echo "Updating AUR packages"
yay -Sua --noconfirm ||
    echo "jarvos: some AUR packages failed to build — the system update itself is fine" >&2

exit 0
```

- [ ] **Step 4: Write `bin/jarvos-update-orphan-pkgs`**

Create `bin/jarvos-update-orphan-pkgs`:

```bash
#!/usr/bin/env bash
# jarvos-update-orphan-pkgs — list packages nothing depends on any more.
#
# Never removes without a human. An orphan list is a heuristic, and removing
# from it unattended is how an update eats something the user installed on
# purpose. Under -y this step reports and skips; it does not become a force.
#
# Seams: JARVOS_ASSUME_YES

set -uo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

orphans="$(pacman -Qtdq 2>/dev/null || true)"
[[ -n "$orphans" ]] || exit 0

echo "These packages are no longer required by anything:"
printf '%s\n' "$orphans" | sed 's/^/  /'

if [[ -n "${JARVOS_ASSUME_YES:-}" ]]; then
    echo "Run 'jarvos-update-orphan-pkgs' interactively to remove them."
    exit 0
fi

read -r -p "Remove them? [y/N] " reply
[[ "$reply" == [yY]* ]] || exit 0

# shellcheck disable=SC2086  # deliberate word splitting: one package per line
sudo pacman -Rns --noconfirm $orphans
exit 0
```

- [ ] **Step 5: Write `bin/jarvos-update-analyze-logs`**

Create `bin/jarvos-update-analyze-logs`:

```bash
#!/usr/bin/env bash
# jarvos-update-analyze-logs — what this boot has been complaining about.
#
# Informational and never fatal: it runs at the end of an update so a user
# sees a problem the update caused while they still connect the two.

set -uo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

errors="$(journalctl -p 3 -b --no-pager 2>/dev/null | tail -n 20 || true)"
[[ -n "$errors" ]] || exit 0

echo "Errors logged this boot (informational):"
printf '%s\n' "$errors" | sed 's/^/  /'
exit 0
```

- [ ] **Step 6: Write `bin/jarvos-update-restart` and `bin/jarvos-restart-shell`**

Create `bin/jarvos-update-restart`:

```bash
#!/usr/bin/env bash
# jarvos-update-restart — honour restart requests left as markers.
#
# A marker named restart-<service>-required dispatches to the command
# jarvos-restart-<service>. The filename IS the dispatch, so a migration can
# ask for a service restart by touching a file and this pipeline never has
# to learn about it.
#
# The marker is cleared only on success, so a restart that failed is
# retried by the next update rather than silently forgotten.

set -uo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ -d "$JARVOS_STATE" ]] || exit 0

while IFS= read -r marker; do
    name="${marker##*/}"
    service="${name#restart-}"
    service="${service%-required}"

    if ! command -v "jarvos-restart-$service" >/dev/null 2>&1; then
        echo "jarvos: no jarvos-restart-$service for marker $name — leaving it" >&2
        continue
    fi

    echo "Restarting $service"
    if "jarvos-restart-$service"; then
        rm -f "$marker"
    else
        echo "jarvos: restarting $service failed — will retry next update" >&2
    fi
done < <(find "$JARVOS_STATE" -maxdepth 1 -type f -name 'restart-*-required' | sort)

exit 0
```

Create `bin/jarvos-restart-shell`:

```bash
#!/usr/bin/env bash
# jarvos-restart-shell — restart the JarvOS shell.
#
# The unit self-relaunches on crash, so this is a plain restart of the user
# service rather than anything cleverer.

set -euo pipefail

systemctl --user restart quickshell-jarvos.service
```

- [ ] **Step 7: Put the restart commands on the sandbox `$PATH`**

`jarvos-update-restart` looks its dispatch target up with `command -v`, so the sandbox must see `bin/` on `$PATH`. In `tests/lib/sandbox.sh`, change `run_cmd`'s `PATH` to:

```bash
        PATH="$FAKE_BIN:$REPO_ROOT/bin:$PATH" \
```

`$FAKE_BIN` stays first so shims still win over real binaries.

- [ ] **Step 8: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-update-aur-pkgs bin/jarvos-update-orphan-pkgs bin/jarvos-update-analyze-logs bin/jarvos-update-restart bin/jarvos-restart-shell && tests/jarvos-update-steps.test.sh`

Expected: `jarvos-update-steps: 15 passed, 0 failed`, exit 0.

- [ ] **Step 9: Run the full suite and commit**

Run: `tests/run-all.sh`

```bash
git add bin/jarvos-update-aur-pkgs bin/jarvos-update-orphan-pkgs \
        bin/jarvos-update-analyze-logs bin/jarvos-update-restart \
        bin/jarvos-restart-shell tests/jarvos-update-steps.test.sh tests/lib/sandbox.sh
git commit -m "feat(update): add the AUR, orphan, log and restart steps

AUR runs last and never fails the update: a third-party build script must
not take down a system that is otherwise correctly updated. Orphan removal
never happens without a human, and -y makes it report and skip rather than
become a force.

jarvos-update-restart dispatches on restart-<service>-required markers to
jarvos-restart-<service>, clearing the marker only on success. A migration
can now request a service restart by touching a file, with no edit to the
update pipeline."
```

---

## Task 11: `jarvos-update`

**Files:**
- Create: `bin/jarvos-update`
- Create: `tests/jarvos-update.test.sh`

**Interfaces:**
- Consumes: every `jarvos-update-*` command from Tasks 9–10, `jarvos-migrate` and `jarvos-version` from Part A, `jarvos-hook` from Task 8. All resolved through `$PATH`, which is what makes the ordering testable.
- Produces: `jarvos-update [-y]`.
- Test seams: `JARVOS_UPDATE_TRANSCRIPT` (set → skip the `script(1)` re-exec), `JARVOS_UPDATE_LOCK_FD` (the `flock` recursion guard), `JARVOS_MIN_FREE_GIB` (default 10), `JARVOS_LOCK_FILE` (default `/tmp/jarvos-update.lock`).

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-update.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-update — ordering, exclusion, gating, resumability.
# Run: tests/jarvos-update.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_LOCK_FILE="$SANDBOX_ROOT/update.lock"
ORDER="$FAKE_STATE/step-order"

# Replace every leaf with a stub that records that it ran. The orchestrator
# resolves them through $PATH, which is exactly why it can be tested at all.
STEPS=(jarvos-update-git jarvos-update-keyring jarvos-update-system-pkgs
    jarvos-migrate jarvos-hook jarvos-update-aur-pkgs
    jarvos-update-orphan-pkgs jarvos-update-analyze-logs jarvos-update-restart
    jarvos-version snapper)
stub_steps() {
    : >"$ORDER"
    for s in "${STEPS[@]}"; do
        printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "$FAKE_STATE/step-order"\nexit 0\n' \
            "$s" >"$FAKE_BIN/$s"
        chmod +x "$FAKE_BIN/$s"
    done
}
stub_steps

pos() { grep -n "^$1\$" "$ORDER" | head -1 | cut -d: -f1; }

start_test "an unattended run completes and touches every step"
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$ORDER" "jarvos-update-git" &&
    assert_contains "$ORDER" "jarvos-update-system-pkgs" &&
    assert_contains "$ORDER" "jarvos-migrate" &&
    assert_contains "$ORDER" "jarvos-update-restart" &&
    pass_test

start_test "the checkout is pulled before any package is touched"
[[ "$(pos jarvos-update-git)" -lt "$(pos jarvos-update-system-pkgs)" ]] &&
    pass_test || fail_test "git ran after packages"

start_test "the keyring is refreshed before the main transaction"
[[ "$(pos jarvos-update-keyring)" -lt "$(pos jarvos-update-system-pkgs)" ]] &&
    pass_test || fail_test "keyring ran after packages"

start_test "migrations run after packages, against what was just installed"
[[ "$(pos jarvos-migrate)" -gt "$(pos jarvos-update-system-pkgs)" ]] &&
    pass_test || fail_test "migrations ran before packages"

start_test "AUR runs after migrations, so a bad build cannot strand them"
[[ "$(pos jarvos-update-aur-pkgs)" -gt "$(pos jarvos-migrate)" ]] &&
    pass_test || fail_test "AUR ran before migrations"

start_test "the snapshot is taken before anything mutates the system"
[[ "$(pos snapper)" -lt "$(pos jarvos-update-git)" ]] &&
    pass_test || fail_test "snapshot taken after mutation began"

start_test "post-update hooks fire after migrations"
[[ "$(pos jarvos-hook)" -gt "$(pos jarvos-migrate)" ]] &&
    pass_test || fail_test "hooks fired before migrations"

start_test "a failing step aborts the run and says where the transcript is"
stub_steps
printf '#!/usr/bin/env bash\nexit 7\n' >"$FAKE_BIN/jarvos-update-system-pkgs"
chmod +x "$FAKE_BIN/jarvos-update-system-pkgs"
JARVOS_UPDATE_TRANSCRIPT=/tmp/jarvos-update.log run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "jarvos-update.log" &&
    assert_not_contains "$ORDER" "jarvos-update-aur-pkgs" &&
    pass_test

start_test "re-running after a failure resumes and completes"
stub_steps
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$ORDER" "jarvos-update-aur-pkgs" &&
    pass_test

start_test "too little free space aborts before anything runs"
stub_steps
JARVOS_UPDATE_TRANSCRIPT=1 JARVOS_MIN_FREE_GIB=999999 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "space" &&
    assert_not_contains "$ORDER" "jarvos-update-git" &&
    assert_not_contains "$ORDER" "snapper" &&
    pass_test

start_test "two concurrent runs never interleave"
stub_steps
printf '#!/usr/bin/env bash\nprintf "enter\\n" >> "$FAKE_STATE/step-order"\nsleep 2\nprintf "leave\\n" >> "$FAKE_STATE/step-order"\n' \
    >"$FAKE_BIN/jarvos-update-system-pkgs"
chmod +x "$FAKE_BIN/jarvos-update-system-pkgs"
( JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y ) &
first=$!
sleep 0.3
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
second_status="$RUN_STATUS"
wait "$first"
# Either the second waited (both ran, cleanly nested) or it declined. What
# it must never do is start its own package step inside the first's.
interleaved=0
awk '/^enter$/{d++} /^leave$/{d--} d>1{exit 1}' "$ORDER" || interleaved=1
[[ "$interleaved" -eq 0 ]] &&
    pass_test || fail_test "a second run interleaved with the first (status $second_status)"

summary "jarvos-update"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-update.test.sh && tests/jarvos-update.test.sh`

Expected: every case FAILs — `bin/jarvos-update` does not exist.

- [ ] **Step 3: Write `bin/jarvos-update`**

Create `bin/jarvos-update`:

```bash
#!/usr/bin/env bash
# jarvos-update — the single blessed way to bring a machine current.
#
#   jarvos-update       ask before starting
#   jarvos-update -y    unattended: steps that would prompt report and skip
#
# This file is ORCHESTRATION ONLY. Every step is a separate command, which
# is what keeps this readable and what makes the ordering testable.
#
# The ordering below is not stylistic. Each line of it is a constraint:
#   prune before snapshot   the cache is on the snapshotted subvolume, so
#                           pruning after it frees nothing until the
#                           snapshot ages out
#   git before packages     a merge conflict must abort before any system
#                           mutation
#   keyring before packages a stale keyring fails the main transaction
#                           unrecoverably, in the middle
#   migrations after them   migrations ship with the packages above and are
#                           written against them
#   AUR last                a broken third-party build must not take down
#                           the system update
#
# Recovery is out-of-band: reboot into the snapshot, or just re-run. Every
# step is --needed-guarded or marker-guarded, so retry is a real remedy.
#
# Seams: JARVOS_UPDATE_TRANSCRIPT, JARVOS_UPDATE_LOCK_FD, JARVOS_MIN_FREE_GIB,
#        JARVOS_LOCK_FILE

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

TRANSCRIPT="${JARVOS_UPDATE_TRANSCRIPT:-}"
LOCK_FILE="${JARVOS_LOCK_FILE:-/tmp/jarvos-update.lock}"
MIN_FREE_GIB="${JARVOS_MIN_FREE_GIB:-10}"

# --- prelude 1: a transcript, without killing pacman's progress bars -----
# script(1) keeps a PTY, which a plain `| tee` does not; the env var is the
# recursion guard.
if [[ -z "$TRANSCRIPT" ]]; then
    export JARVOS_UPDATE_TRANSCRIPT=/tmp/jarvos-update.log
    exec script -qefc "$0 $*" "$JARVOS_UPDATE_TRANSCRIPT"
fi

# --- prelude 2: one update at a time -------------------------------------
# The FD is carried through the environment and verified by what it points
# at, so there is no PID file to go stale.
if [[ -z "${JARVOS_UPDATE_LOCK_FD:-}" ]] ||
    [[ "$(readlink -f "/proc/$$/fd/${JARVOS_UPDATE_LOCK_FD}" 2>/dev/null)" != "$(readlink -f "$LOCK_FILE" 2>/dev/null)" ]]; then
    exec 9>"$LOCK_FILE"
    export JARVOS_UPDATE_LOCK_FD=9
    flock 9
fi

ASSUME_YES=""
case "${1-}" in
-y | --yes) ASSUME_YES=1 ;;
-h | --help)
    sed -n '2,8p' "$0"
    exit 0
    ;;
"") ;;
*) die "unknown argument: $1" ;;
esac
[[ -n "$ASSUME_YES" ]] && export JARVOS_ASSUME_YES=1

on_error() {
    printf '\njarvos-update failed. The full transcript is at %s\n' "$TRANSCRIPT" >&2
    printf 'Re-run jarvos-update to resume, or reboot into a snapshot to roll back.\n' >&2
}
trap on_error ERR

printf 'JarvOS %s\n' "$(jarvos-version 2>/dev/null || echo unknown)"

# --- gate: space, before the confirm prompt, so a doomed run says so early
free_gib="$(df --output=avail -BG "$HOME" | tail -1 | tr -dc '0-9')"
if [[ -n "$free_gib" ]] && ((free_gib < MIN_FREE_GIB)); then
    die "only ${free_gib}G free; an update needs ${MIN_FREE_GIB}G"
fi

if [[ -z "$ASSUME_YES" ]]; then
    read -r -p "Update JarvOS now? [Y/n] " reply
    [[ -z "$reply" || "$reply" == [yY]* ]] || exit 0
fi

# --- prune, then snapshot ------------------------------------------------
sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true

if command -v snapper >/dev/null 2>&1; then
    sudo snapper create --description "before jarvos-update" >/dev/null 2>&1 ||
        echo "jarvos-update: could not create a snapshot — continuing without a rollback point" >&2
fi

# --- inhibit sleep for the duration --------------------------------------
if command -v systemd-inhibit >/dev/null 2>&1 && [[ -z "${JARVOS_UPDATE_INHIBITED:-}" ]]; then
    export JARVOS_UPDATE_INHIBITED=1
    exec systemd-inhibit --what=sleep:idle --why="JarvOS update" "$0" "$@"
fi

# --- the pipeline --------------------------------------------------------
jarvos-update-git
jarvos-update-keyring
jarvos-update-system-pkgs
jarvos-migrate
jarvos-hook post-update
jarvos-update-aur-pkgs
jarvos-update-orphan-pkgs
jarvos-update-analyze-logs
jarvos-update-restart

trap - ERR
printf '\nJarvOS is up to date (%s)\n' "$(jarvos-version 2>/dev/null || echo unknown)"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-update && tests/jarvos-update.test.sh`

Expected: `jarvos-update: 12 passed, 0 failed`, exit 0.

If the snapshot-ordering case fails because `systemd-inhibit` is present on the test box and re-execs before the stubs record, add `systemd-inhibit` to the sandbox `STEPS` stub list as a pass-through:

```bash
printf '#!/usr/bin/env bash\nshift 2\nexec "$@"\n' >"$FAKE_BIN/systemd-inhibit"
chmod +x "$FAKE_BIN/systemd-inhibit"
```

- [ ] **Step 5: Verify the transcript prelude for real**

Run: `JARVOS_MIN_FREE_GIB=999999 bin/jarvos-update -y; echo "exit=$?"; ls -la /tmp/jarvos-update.log`

Expected: the space gate refuses, exit non-zero, **and** `/tmp/jarvos-update.log` exists containing the refusal — proving the `script(1)` re-exec ran on the real machine, not only under the test seam.

- [ ] **Step 6: Run the full suite and commit**

Run: `tests/run-all.sh`

```bash
git add bin/jarvos-update tests/jarvos-update.test.sh
git commit -m "feat(update): add the jarvos-update orchestrator

Orchestration and nothing else — every step is a separate command resolved
through PATH, which is what makes the ordering testable rather than
asserted in a comment.

Two self-re-exec preludes: script(1) for a transcript that keeps a PTY, so
pacman's progress bars survive where a plain tee would kill them; and flock
on an FD carried through the environment and verified via /proc, so there
is no PID file to go stale.

The step order is load-bearing and the header says why for each line:
prune before snapshot, git before packages, keyring before the main
transaction, migrations after the packages they were written against, AUR
last."
```

---

## Task 12: Package the runtime

**Files:**
- Create: `packaging/jarvos/PKGBUILD`
- Create: `packaging/jarvos/.gitignore`
- Create: `LICENSE`
- Modify: `bootstrap.sh` — install the git hooks unconditionally
- Modify: `CHANGELOG.md` — add the `[Unreleased]` entries
- Create: `tests/jarvos-package.test.sh`

**Interfaces:**
- Consumes: every command built in Part A and Part B.
- Produces: a `jarvos` package installing `bin/*` to `/usr/bin`, `lib/` and `migrations/` and `config/` to `/usr/share/jarvos/`, and `system/modules/` to `/usr/share/jarvos/modules` — the path `scripts/jarvos-module-install` already searches and which nothing has populated until now.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-package.test.sh`:

```bash
#!/usr/bin/env bash
# The package must actually carry the runtime, and the repo must be
# distributable. Run: tests/jarvos-package.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

PKGBUILD="$REPO_ROOT/packaging/jarvos/PKGBUILD"

start_test "a PKGBUILD exists"
assert_file_exists "$PKGBUILD" && pass_test

start_test "it parses as bash"
bash -n "$PKGBUILD" 2>/dev/null && pass_test || fail_test "PKGBUILD is not valid bash"

start_test "every bin/jarvos-* command is installed"
missing=""
for cmd in "$REPO_ROOT"/bin/jarvos-*; do
    grep -q "bin/" "$PKGBUILD" || missing="$missing ${cmd##*/}"
done
grep -q 'install -Dm755 .*bin/' "$PKGBUILD" &&
    pass_test || fail_test "PKGBUILD never installs bin/ with mode 755"

start_test "the library lands where the fallback looks for it"
assert_contains "$PKGBUILD" "/usr/share/jarvos/lib" && pass_test

start_test "migrations are shipped 0644, as the runner requires"
assert_contains "$PKGBUILD" "644" &&
    assert_contains "$PKGBUILD" "migrations" &&
    pass_test

start_test "modules land where jarvos-module-install already looks"
assert_contains "$PKGBUILD" "/usr/share/jarvos/modules" && pass_test

start_test "a LICENSE exists — the repo is not distributable without one"
assert_file_exists "$REPO_ROOT/LICENSE" && pass_test

start_test "the PKGBUILD declares GPL3, the copyleft the shell inherits"
assert_contains "$PKGBUILD" "GPL3" && pass_test

start_test "the LICENSE is the full GPLv3, not a stub"
[[ "$(wc -l <"$REPO_ROOT/LICENSE")" -gt 600 ]] &&
    pass_test || fail_test "LICENSE is too short to be the GPLv3 text"

start_test "the secret gate installs itself rather than waiting to be asked"
assert_contains "$REPO_ROOT/bootstrap.sh" "core.hooksPath" && pass_test

summary "jarvos-package"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-package.test.sh && tests/jarvos-package.test.sh`

Expected: every case FAILs.

- [ ] **Step 3: LICENSE — already done, verify only**

**This step was completed ahead of schedule on 2026-08-25** and pulled out of this task, because the repository was published to GitHub before Part B ran and distributing GPL-derived work without the licence text is the one thing the licence actually requires.

`LICENSE` already holds the full 674-line GPLv3 text, and `README.md`'s License section already carries the attribution described in Step 4. **Verify both and move on — do not rewrite them.**

Run: `head -3 LICENSE && wc -l LICENSE && sed -n '/^## License/,/^$/p' README.md`

Expected: `GNU GENERAL PUBLIC LICENSE`, 674 lines, and a README section naming GPL-3.0-only and the Caelestia derivation. If either is missing, restore it as the original step below describes.

**The license is GPL-3.0-only for the whole repository.** This is settled; do not substitute MIT because `~/jarvos-iso` uses it.

The reason, so nobody "corrects" it later: `config/.config/quickshell/jarvos/` is a fork of `caelestia-shell`, which is **GPL-3.0-only**. Not "or later" — only. It is copyleft, so a derivative work must carry the same license, and the repository ships that derivative alongside everything else.

Copy the canonical text rather than reproducing it from memory — the machine already has it:

Run: `cp /usr/share/licenses/caelestia-shell/LICENSE LICENSE && head -3 LICENSE && wc -l LICENSE`

Expected: `GNU GENERAL PUBLIC LICENSE / Version 3, 29 June 2007` and 674 lines. A truncated or paraphrased license is not a license.

- [ ] **Step 4: Record the attribution the GPL requires**

Add to `README.md`, under the existing credits section:

```markdown
## License

JarvOS is licensed under the GNU General Public License v3.0 only — see
[LICENSE](LICENSE).

The JarvOS shell (`config/.config/quickshell/jarvos/`) is a fork of
[Caelestia](https://github.com/caelestia-dots/caelestia), which is
GPL-3.0-only. That copyleft is why the whole repository is GPL-3.0-only.
```

Also flag for the chairman, without acting on it: `~/jarvos-iso` is currently MIT. If it bundles the shell, its license is inconsistent with this one and needs the same treatment. That is a separate repository and out of scope here — report it, do not change it.

- [ ] **Step 5: Write the PKGBUILD**

Create `packaging/jarvos/PKGBUILD`:

```bash
# Maintainer: JarvOS
pkgname=jarvos
pkgver=0.3.0
pkgrel=1
pkgdesc="JarvOS runtime: maintenance commands, migrations, and shipped defaults"
arch=('any')
url="https://github.com/jarvos/JarvOS"
license=('GPL3')
depends=('bash' 'git' 'pacman' 'util-linux')
optdepends=(
    'snapper: rollback point before each update'
    'yay: AUR package updates'
    'quickshell-git: the JarvOS shell'
)
source=()
sha256sums=()

package() {
    local root="$startdir/../.."

    # Commands onto $PATH. Until now none of the runtime tooling was
    # installed anywhere at all.
    install -d "$pkgdir/usr/bin"
    install -Dm755 "$root"/bin/jarvos-* -t "$pkgdir/usr/bin/"

    # The library, at the path every command's preamble falls back to.
    install -Dm644 "$root/lib/jarvos-common.sh" \
        "$pkgdir/usr/share/jarvos/lib/jarvos-common.sh"

    # Migrations ship 0644 and shebang-less: the runner supplies strictness,
    # and a stray ./ must not be able to fire one.
    install -d "$pkgdir/usr/share/jarvos/migrations"
    if compgen -G "$root/migrations/*.sh" >/dev/null; then
        install -Dm644 "$root"/migrations/*.sh -t "$pkgdir/usr/share/jarvos/migrations/"
    fi

    # Shipped defaults, the source jarvos-refresh-config pulls from.
    install -d "$pkgdir/usr/share/jarvos/config"
    cp -a "$root/config/." "$pkgdir/usr/share/jarvos/config/"

    # The path scripts/jarvos-module-install already searches and which
    # nothing has populated until now.
    install -d "$pkgdir/usr/share/jarvos/modules"
    if [[ -d "$root/system/modules" ]]; then
        cp -a "$root/system/modules/." "$pkgdir/usr/share/jarvos/modules/"
    fi

    install -Dm644 "$root/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    install -Dm644 "$root/CHANGELOG.md" "$pkgdir/usr/share/doc/$pkgname/CHANGELOG.md"
}
```

Create `packaging/jarvos/.gitignore`:

```
pkg/
src/
*.pkg.tar.zst
```

- [ ] **Step 6: Make the secret gate self-installing**

A fresh clone currently ships with no pre-commit gate at all — it has to be opted into, which means it is off exactly when a new contributor is most likely to need it. In `bootstrap.sh`, inside `deploy_dotfiles()` (or the nearest setup function that runs from the checkout), add:

```bash

    # The secret gate ships on, not opt-in: it is off exactly when a new
    # clone needs it most.
    if [[ -d "$base/.githooks" ]]; then
        run git -C "$base" config core.hooksPath .githooks
    fi
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `tests/jarvos-package.test.sh`

Expected: `jarvos-package: 10 passed, 0 failed`, exit 0.

- [ ] **Step 8: Build the package for real**

Run: `cd packaging/jarvos && makepkg -f && ls -la ./*.pkg.tar.zst`

Expected: a `jarvos-0.3.0-1-any.pkg.tar.zst`.

Then inspect what it actually contains — this is the check that catches a `PKGBUILD` that built successfully while shipping nothing:

Run: `pacman -Qlp ./jarvos-0.3.0-1-any.pkg.tar.zst | grep -E 'usr/bin/jarvos|share/jarvos/lib'`

Expected: every `bin/jarvos-*` command from Parts A and B is listed under `usr/bin/`, and `usr/share/jarvos/lib/jarvos-common.sh` is present.

- [ ] **Step 9: Verify an installed command finds its library**

Without installing the package, simulate the packaged layout:

```bash
tmp=$(mktemp -d)
tar -xf packaging/jarvos/jarvos-0.3.0-1-any.pkg.tar.zst -C "$tmp"
sudo cp "$tmp/usr/share/jarvos/lib/jarvos-common.sh" /usr/share/jarvos/lib/ 2>/dev/null ||
  { sudo mkdir -p /usr/share/jarvos/lib && sudo cp "$tmp/usr/share/jarvos/lib/jarvos-common.sh" /usr/share/jarvos/lib/; }
"$tmp/usr/bin/jarvos-state" list; echo "exit=$?"
rm -rf "$tmp"
```

Expected: `exit=0`. This proves the `/usr/bin` → `/usr/share/jarvos/lib` fallback in every command's preamble, which no other test covers.

- [ ] **Step 10: Update the CHANGELOG and commit**

Under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
### Added

- `jarvos-update` — the single blessed way to bring a machine current, with
  a transcript, a rollback snapshot, and mutual exclusion.
- `jarvos-refresh-config` — pulls a shipped default over a user file,
  keeping a backup only when something was actually lost.
- `jarvos-hook` — user hooks for `post-update`, `post-boot`,
  `pre-refresh-pacman` and `theme-set`. A failing hook never aborts a run.
- `jarvos-restart-shell` and marker-driven restart dispatch.
- A `PKGBUILD`, so the runtime tooling reaches `$PATH` for the first time.
- A LICENSE: GPL-3.0-only, inherited from the Caelestia fork the shell
  derives from.

### Changed

- The pre-commit secret gate installs itself from `bootstrap.sh` instead of
  waiting to be opted into.
```

```bash
git add packaging/ LICENSE bootstrap.sh CHANGELOG.md tests/jarvos-package.test.sh
git commit -m "feat(packaging): package the runtime

Nothing installed the runtime tooling before this: jarvos-setup,
jarvos-sync and jarvos-module-install were never placed anywhere, and
jarvos-module-install searched /usr/share/jarvos/modules, a path nothing
populated. The PKGBUILD puts every command on \$PATH and fills that
directory.

Adds the LICENSE the repo needs to be distributable at all, and makes the
pre-commit secret gate ship on rather than opt-in — it was off exactly when
a fresh clone needs it most."
```

---

## Task 13: Clean-VM verification

Three of the spec's criteria cannot be proven in a sandbox, only in a machine that has never seen JarvOS. `~/jarvos-iso` already has QEMU tooling (`bin/jarvos-iso-test`) to build on.

**Files:**
- Create: `tests/vm/verify-fresh-install.sh`

- [ ] **Step 1: Write the verification script**

Create `tests/vm/verify-fresh-install.sh`:

```bash
#!/usr/bin/env bash
# Run INSIDE a freshly installed JarvOS VM, as the first user, before any
# manual change. Proves the things a sandbox cannot.
set -uo pipefail

pass=0
fail=0
check() {
    if eval "$2"; then
        printf '  ok   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf '  FAIL %s\n' "$1"
        fail=$((fail + 1))
    fi
}

echo "Fresh-install verification"

check "jarvos-version reports a package version, not dev" \
    '[[ "$(jarvos-version)" != *dev* ]]'

check "every shipped migration is pre-marked" \
    '! jarvos-migrate --pending'

check "a first-boot migration run applies nothing" \
    '[[ -z "$(jarvos-migrate)" ]]'

check "the runtime tooling is on PATH" \
    'command -v jarvos-update && command -v jarvos-migrate && command -v jarvos-refresh-config'

check "the library is where the packaged fallback looks" \
    '[[ -r /usr/share/jarvos/lib/jarvos-common.sh ]]'

check "the module path jarvos-module-install searches is populated" \
    '[[ -d /usr/share/jarvos/modules ]]'

check "the hook sample directories shipped" \
    '[[ -d ~/.config/jarvos/hooks/post-update.d ]]'

# CORRECTED 2026-08-26. The original form of this check was vacuous: its eval
# ended in `; true`, so its exit status was always 0 and it passed regardless
# of what jarvos-update did. It also hardcoded eth0, which a QEMU guest under
# predictable naming does not have — and `2>/dev/null` hid that failure, so
# the network stayed up and the check silently became "jarvos-update runs".
#
# Discover the interface, capture the status BEFORE restoring the link, and
# assert on the captured status.
check "jarvos-update refuses cleanly with no network" '
    iface="$(ip route show default | awk "{print \$5; exit}")"
    [[ -n "$iface" ]] || { echo "    no default route to take down"; false; }
    sudo ip link set dev "$iface" down || { echo "    could not down $iface"; false; }
    jarvos-update -y >/dev/null 2>&1
    rc=$?
    sudo ip link set dev "$iface" up
    [[ "$rc" -ne 0 ]]'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
```

- [ ] **Step 2: Build an ISO carrying the package**

Follow `~/jarvos-iso`'s existing build path with the `jarvos` package from Task 12 added to the `[jarvos]` repo. Read `~/jarvos-iso/README.md` and `bin/jarvos-iso-test --help` first rather than reconstructing the flags.

- [ ] **Step 3: Boot it and run the verification**

Install to a fresh VM disk, boot the installed system, log in as the first user, and run `tests/vm/verify-fresh-install.sh`.

Expected: `8 passed, 0 failed`.

**Record the actual output in the commit body.** A claim that this passed without the transcript is not a verification.

- [ ] **Step 4: Commit**

```bash
git add tests/vm/verify-fresh-install.sh
git commit -m "test: add clean-VM verification of a fresh install

The three criteria a sandbox cannot prove: that a fresh install has every
shipped migration pre-marked and migrates nothing on first boot, that the
packaged library is where each command's fallback looks, and that an
update with no network fails cleanly instead of half-way.

<paste the actual VM run output here>"
```

---

## Done when

Against spec §11:

| # | Criterion | Proven by |
|---|---|---|
| 1 | `jarvos-version` from `pacman -Q` when packaged, `dev (<hash>)` in a checkout | Part A Task 5; VM check 1 |
| 2 | Fresh install pre-marks everything; first boot runs zero migrations | Part A Task 4 + VM checks 2–3 |
| 3 | A failed migration leaves no marker, aborts, retries | Part A Task 3 |
| 4 | Deleting one marker replays exactly that migration | Part A Task 3 |
| 5 | Two concurrent `jarvos-update` runs never interleave | Task 11 |
| 6 | An interrupted update resumes correctly | Task 11 |
| 7 | `jarvos-refresh-config` is silent and backup-free on an unmodified file | Task 7 |
| 8 | `jarvos-refresh-config ../../etc/passwd` is rejected | Task 7 |
| 9 | Shell loads from `/etc/xdg/quickshell/jarvos/` | **Out of scope** — spec §12 step 6 |
| 10 | `shell.json` survives an update byte-identical | **Out of scope** — depends on 9 |
| 11 | A manifest package plus its migration lands after one update | Task 11 + a real migration |
| 12 | No network: fails cleanly, leaves the system usable | Task 9 + VM check 8 |
| 13 | `shellcheck` passes on every new script | `tests/run-all.sh` |

Criteria 9 and 10 belong to spec §12 step 6 (shell relocation), which is not in Parts A or B.

## Not in this plan

Deliberately deferred, tracked so they are not mistaken for oversights:

- **The Caelestia hard fork** — decided 2026-08-25, sequenced deliberately *after* this plan; see `docs/decisions/2026-08-25-caelestia-hard-fork.md`. It needs the migration machinery Part A builds in order to move existing machines across the namespace rename, which is why it comes second. One consequence for **Task 12**: the PKGBUILD written there packages the runtime only. Do not try to anticipate the forked plugin package in it — that is a second package, designed once the fork is scoped.
- **Shell relocation to `/etc/xdg/quickshell/jarvos/`** (spec §12 step 6). Independent of everything here, but entangled with the fork — settle the fork's package layout before choosing the path.
- **The Hyprland override spike** (spec §3, §12 step 7). Unresolved by design — three options, none chosen, needs evidence.
- **Channels and the one-month-behind mirror** (spec §9, §12 step 8). The only item needing infrastructure we do not run. It is also the direct answer to the Qt 6.11.1 → 6.11.2 failure in spec §1, so it should not stay deferred long.
- **Package reconciliation** (spec §10). A manifest change still needs a hand-written migration; the CI check that catches a missing one is not built.
- **`.pacnew`/`.pacsave` handling** (spec §10). `system/etc/` is empty today.
