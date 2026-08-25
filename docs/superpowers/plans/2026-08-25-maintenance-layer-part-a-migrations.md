# JarvOS Maintenance Layer — Part A: Primitives, Migrations, Versioning

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give an installed JarvOS machine the ability to say which version it is running and to apply one-time repair scripts shipped by later releases, exactly once, per user.

**Architecture:** Four small `bash` commands in `bin/` sharing one sourced library that resolves `$JARVOS_PATH` (git checkout or `/usr/share/jarvos`) and `$JARVOS_STATE` (`$XDG_STATE_HOME/jarvos`). Migrations are shebang-less `0644` files in `migrations/` named for the commit timestamp of the release that introduced them; a glob over that directory *is* the ordering. Applied state is one empty marker file per migration per user, and installers pre-mark every shipped migration so migration N never has to be safe on a machine that never had state N−1.

**Tech Stack:** bash 5, `shellcheck`, the repo's existing hand-rolled test harness (`tests/lib/sandbox.sh` — fake `$HOME`, `$PATH` of shims for pacman/yay/systemctl/sudo). No new dependencies. **Do not introduce `bats`** — it is not installed and the house style is `tests/*.test.sh`.

**Source spec:** `docs/superpowers/specs/2026-08-25-jarvos-maintenance-layer-design.md` §4, §5, §8, §12 steps 1–2.

## Global Constraints

- Every new script passes `shellcheck` with zero findings. This is a gate, not an aspiration.
- Every new script is `bash`, starts `#!/usr/bin/env bash`, and sets `set -euo pipefail`.
- Migration files are mode `0644` and carry **no shebang**. The runner supplies strictness.
- State lives under `${XDG_STATE_HOME:-$HOME/.local/state}/jarvos` — never `~/.config`, never `/var`.
- Migration markers are **per user**: `$JARVOS_STATE/migrations/<filename>`.
- A migration's marker is written **only on success**. A failed migration aborts the whole run and retries next invocation.
- No script may exceed 120 lines. If one does, the design is wrong.
- Commands are named `jarvos-<noun>` or `jarvos-<noun>-<verb>` and live in `bin/`.
- Touch only what the task names. Do not reformat or "improve" adjacent code.
- **Do not fix pre-existing `shellcheck` findings** in `scripts/jarvos-sync`, `bootstrap.sh`, or `install.sh`. Scope the new gate to new files.

---

## File Structure

| Path | Responsibility |
|---|---|
| `lib/jarvos-common.sh` | Sourced by every `jarvos-*` command. Resolves `JARVOS_PATH`, `JARVOS_STATE`. Provides `die`. Nothing else. |
| `bin/jarvos-state` | Create/remove/query/list runtime markers. |
| `bin/jarvos-pkg-present`, `bin/jarvos-pkg-missing` | Query package installation. Exit status is the answer. |
| `bin/jarvos-pkg-add`, `bin/jarvos-pkg-drop` | Install/remove packages, re-verifying after. The vocabulary migrations are written in. |
| `bin/jarvos-migrate` | Run pending migrations. Also `--pending` and `--mark-all`. |
| `bin/jarvos-version` | Report the running version. |
| `migrations/` | Ships empty (with `.gitkeep`) until Part B needs one. |
| `tests/lib/sandbox.sh` | **Modified.** Gains a generic `run_cmd`; keeps `run_sync` untouched. |
| `tests/jarvos-state.test.sh` | Markers appear, disappear, list, refuse to escape. |
| `tests/jarvos-pkg.test.sh` | Present/missing/add/drop against the pacman shim, incl. the lying-pacman case. |
| `tests/jarvos-migrate.test.sh` | Ordering, marker-on-success-only, replay, `--pending`, `--mark-all`, pacman-busy deferral. |
| `tests/run-all.sh` | Runs every `tests/*.test.sh` then `shellcheck` over the new files. |
| `CHANGELOG.md` | Release boundaries. Created at Task 6. |

### The shared preamble

Every command in `bin/` opens with exactly this, and nothing else, to find its library. It is repeated verbatim rather than factored out because the thing being located *is* the factoring:

```bash
# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib
```

From a checkout, `bin/../lib/` resolves. From `/usr/bin/jarvos-migrate`, `/usr/lib/jarvos-common.sh` is not readable, so it falls through to the packaged path. No build-time path munging.

---

## Task 1: Shared library, `jarvos-state`, and a generic test runner

**Files:**
- Create: `lib/jarvos-common.sh`
- Create: `bin/jarvos-state`
- Create: `tests/jarvos-state.test.sh`
- Create: `tests/run-all.sh`
- Modify: `tests/lib/sandbox.sh` (append `run_cmd` after `run_sync`, around line 324)

**Interfaces:**
- Produces: `lib/jarvos-common.sh` exporting shell variables `JARVOS_PATH` (absolute, no trailing slash) and `JARVOS_STATE` (absolute), and function `die <message> [exit-code]` which prints `<progname>: <message>` to stderr and exits (default 1).
- Produces: `bin/jarvos-state` with subcommands `set <name>`, `clear <name>`, `check <name>`, `list`.
- Produces: test helper `run_cmd <command-name> [args...]` which runs `$REPO_ROOT/bin/<command-name>` in the sandbox and sets `RUN_OUT` and `RUN_STATUS`. Every later task's tests consume it.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-state.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-state — markers appear, disappear, answer, list, and cannot escape
# the state directory. Run: tests/jarvos-state.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

STATE="$FAKE_HOME/.local/state/jarvos"

start_test "set creates the marker"
run_cmd jarvos-state set restart-shell-required
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$STATE/restart-shell-required" &&
    pass_test

start_test "set is idempotent"
run_cmd jarvos-state set restart-shell-required
assert_status "$RUN_STATUS" 0 && pass_test

start_test "check answers yes for a marker that exists"
run_cmd jarvos-state check restart-shell-required
assert_status "$RUN_STATUS" 0 && pass_test

start_test "check answers no for a marker that does not"
run_cmd jarvos-state check never-set
assert_status "$RUN_STATUS" 1 && pass_test

start_test "list prints the marker names, not paths"
run_cmd jarvos-state set second-marker
run_cmd jarvos-state list
assert_stdout_contains "$RUN_OUT" "restart-shell-required" &&
    assert_stdout_contains "$RUN_OUT" "second-marker" &&
    assert_not_contains <(printf '%s' "$RUN_OUT") "/" &&
    pass_test

start_test "clear removes the marker"
run_cmd jarvos-state clear restart-shell-required
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$STATE/restart-shell-required" &&
    pass_test

start_test "clear on a missing marker is not an error"
run_cmd jarvos-state clear never-set
assert_status "$RUN_STATUS" 0 && pass_test

start_test "list on an empty state dir prints nothing and exits 0"
run_cmd jarvos-state clear second-marker
run_cmd jarvos-state list
assert_status "$RUN_STATUS" 0 &&
    { [[ -z "$RUN_OUT" ]] || fail_test "expected no output, got: $RUN_OUT"; } &&
    pass_test

start_test "a name containing a slash is refused"
run_cmd jarvos-state set ../../escaped
assert_status "$RUN_STATUS" 1 &&
    assert_no_file "$FAKE_HOME/.local/escaped" &&
    assert_no_file "$FAKE_HOME/.local/state/escaped" &&
    pass_test

start_test "an empty name is refused"
run_cmd jarvos-state set ""
assert_status "$RUN_STATUS" 1 && pass_test

start_test "an unknown subcommand is refused"
run_cmd jarvos-state frobnicate thing
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-state"
```

- [ ] **Step 2: Add the generic runner to the sandbox**

Append to `tests/lib/sandbox.sh`, immediately after the `run_sync` function (it ends at the line `}` following `RUN_STATUS="$status"`, around line 324) and before `home_file`:

```bash
# Run any bin/jarvos-* command inside the sandbox. Exported variables set by
# the caller carry through, so a test can set e.g. JARVOS_LOCK_WAIT=0 before
# calling. JARVOS_PATH points at the fake baseline so migrations and shipped
# defaults come from fixtures; the command still finds its real library via
# the bin/../lib fallback in its preamble.
run_cmd() {
    local cmd="$1"
    shift
    local out status
    set +e
    out="$(env \
        HOME="$FAKE_HOME" \
        PATH="$FAKE_BIN:$PATH" \
        XDG_STATE_HOME="$FAKE_HOME/.local/state" \
        FAKE_STATE="$FAKE_STATE" \
        JARVOS_PATH="$FAKE_BASE" \
        "$REPO_ROOT/bin/$cmd" "$@" 2>&1)"
    status=$?
    set -e
    # shellcheck disable=SC2034  # read by the callers in the test files
    RUN_OUT="$out"
    # shellcheck disable=SC2034
    RUN_STATUS="$status"
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `tests/jarvos-state.test.sh`

Expected: every case FAILs, because `bin/jarvos-state` does not exist. Output ends with a non-zero `summary` line such as `jarvos-state: 0 passed, 11 failed`.

- [ ] **Step 4: Write the shared library**

Create `lib/jarvos-common.sh`:

```bash
# shellcheck shell=bash
# Shared resolution for every jarvos-* command. Sourced, never executed.
#
# JARVOS_PATH  the runtime tree: a git checkout in development, and
#              /usr/share/jarvos once packaged. Derived from where THIS file
#              sits, so there is exactly one thing to get right.
# JARVOS_STATE per-user runtime state: markers, migration bookkeeping.

_jarvos_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JARVOS_PATH="${JARVOS_PATH:-$(dirname "$_jarvos_lib_dir")}"
JARVOS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/jarvos"
unset _jarvos_lib_dir

die() {
    printf '%s: %s\n' "${0##*/}" "$1" >&2
    exit "${2:-1}"
}
```

- [ ] **Step 5: Write `bin/jarvos-state`**

Create `bin/jarvos-state`:

```bash
#!/usr/bin/env bash
# jarvos-state — runtime markers under $XDG_STATE_HOME/jarvos.
#
#   jarvos-state set <name>     create the marker
#   jarvos-state clear <name>   remove it (missing is not an error)
#   jarvos-state check <name>   exit 0 if it exists, 1 if it does not
#   jarvos-state list           print every marker name, one per line
#
# The filename is the dispatch. A migration asks for a service restart by
# touching restart-<service>-required; nothing in the update pipeline has to
# learn about it.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

# A marker name is a single path component. Anything else is a caller bug
# that would write outside the state directory.
require_name() {
    case "${1-}" in
        "" | */* | .*) die "not a valid marker name: '${1-}'" ;;
    esac
}

case "${1-}" in
set)
    require_name "${2-}"
    mkdir -p "$JARVOS_STATE"
    : >"$JARVOS_STATE/$2"
    ;;
clear)
    require_name "${2-}"
    rm -f "$JARVOS_STATE/$2"
    ;;
check)
    require_name "${2-}"
    [[ -e "$JARVOS_STATE/$2" ]]
    ;;
list)
    [[ -d "$JARVOS_STATE" ]] || exit 0
    find "$JARVOS_STATE" -maxdepth 1 -type f -printf '%f\n' | sort
    ;;
-h | --help)
    sed -n '2,12p' "$0"
    ;;
*)
    die "usage: jarvos-state set|clear|check <name> | list"
    ;;
esac
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-state tests/jarvos-state.test.sh && tests/jarvos-state.test.sh`

Expected: `jarvos-state: 11 passed, 0 failed`, exit 0.

- [ ] **Step 7: Write the suite runner**

Create `tests/run-all.sh`:

```bash
#!/usr/bin/env bash
# Every test suite, then shellcheck over the maintenance-layer scripts.
# Scoped deliberately: pre-existing findings in bootstrap.sh / install.sh /
# scripts/ are not this gate's business.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

for t in tests/*.test.sh; do
    printf '\n== %s\n' "$t"
    "$t" || fail=1
done

printf '\n== shellcheck\n'
if shellcheck bin/jarvos-* lib/*.sh tests/run-all.sh tests/*.test.sh tests/lib/*.sh; then
    printf '  ok   no findings\n'
else
    fail=1
fi

exit "$fail"
```

- [ ] **Step 8: Run the suite runner**

Run: `chmod +x tests/run-all.sh && tests/run-all.sh`

Expected: the two pre-existing `jarvos-sync` suites pass, `jarvos-state` passes, `shellcheck` reports `ok no findings`, exit 0.

If `shellcheck` flags the pre-existing `tests/*.test.sh` or `tests/lib/sandbox.sh`, fix only what your changes introduced and drop the pre-existing files from the `shellcheck` argument list, noting it in the commit body.

- [ ] **Step 9: Commit**

```bash
git add lib/jarvos-common.sh bin/jarvos-state tests/jarvos-state.test.sh \
        tests/run-all.sh tests/lib/sandbox.sh
git commit -m "feat(runtime): add jarvos-state markers and a shared command library

State markers under \$XDG_STATE_HOME/jarvos, where the filename is the
dispatch: anything can request work by touching a name something else looks
for. lib/jarvos-common.sh resolves JARVOS_PATH from its own location, so a
checkout and a /usr/share/jarvos install need no separate code path.

tests/run-all.sh runs every suite plus shellcheck over the new scripts."
```

---

## Task 2: Package primitives

**Files:**
- Create: `bin/jarvos-pkg-present`
- Create: `bin/jarvos-pkg-missing`
- Create: `bin/jarvos-pkg-add`
- Create: `bin/jarvos-pkg-drop`
- Create: `tests/jarvos-pkg.test.sh`
- Modify: `tests/lib/sandbox.sh` — extend the `pacman` shim inside `make_shims` (starts line 199) to handle `-R` and a lying-install mode

**Interfaces:**
- Consumes: `lib/jarvos-common.sh` (`die`), `run_cmd` from Task 1.
- Produces: four commands. `jarvos-pkg-present <pkg>` and `jarvos-pkg-missing <pkg>` take exactly one package and answer via exit status (0 = yes). `jarvos-pkg-add <pkg>...` and `jarvos-pkg-drop <pkg>...` take one or more, act only on those that need it, and verify the result. These are the vocabulary every migration is written in.

- [ ] **Step 1: Extend the pacman shim**

In `tests/lib/sandbox.sh`, inside `make_shims`, replace the `pacman` heredoc with this version. The two additions are the `-R*` branch and the `PACMAN_LIES` escape, which reproduces pacman's real habit of exiting 0 without installing:

```bash
    cat >"$FAKE_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    "-Qqe")  cat "$FAKE_STATE/pacman-explicit" ;;
    "-Qq")   cat "$FAKE_STATE/pacman-explicit" ;;
    "-Qqm")  cat "$FAKE_STATE/pacman-foreign" ;;
    -Q*)     for p in "${@:2}"; do grep -qxF "$p" "$FAKE_STATE/pacman-explicit" || exit 1; done ;;
    -S*)     [[ -e "$FAKE_STATE/pacman-lies" ]] && exit 0
             printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/pacman-installed"
             printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/pacman-explicit" ;;
    -R*)     for p in "${@:2}"; do
                 [[ "$p" == --* ]] && continue
                 printf '%s\n' "$p" >> "$FAKE_STATE/pacman-removed"
                 grep -vxF "$p" "$FAKE_STATE/pacman-explicit" > "$FAKE_STATE/.tmp" || true
                 mv "$FAKE_STATE/.tmp" "$FAKE_STATE/pacman-explicit"
             done ;;
    *)       exit 0 ;;
esac
EOF
```

- [ ] **Step 2: Write the failing test**

Create `tests/jarvos-pkg.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-pkg-* — the vocabulary migrations are written in.
# Run: tests/jarvos-pkg.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

printf 'base\nlinux\nhyprland\n' >"$FAKE_STATE/pacman-explicit"
: >"$FAKE_STATE/pacman-installed"
: >"$FAKE_STATE/pacman-removed"

start_test "present answers yes for an installed package"
run_cmd jarvos-pkg-present hyprland
assert_status "$RUN_STATUS" 0 && pass_test

start_test "present answers no for one that is not installed"
run_cmd jarvos-pkg-present mpv-mpris
assert_status "$RUN_STATUS" 1 && pass_test

start_test "missing is the inverse of present"
run_cmd jarvos-pkg-missing mpv-mpris
assert_status "$RUN_STATUS" 0 && pass_test
run_cmd jarvos-pkg-missing hyprland
assert_status "$RUN_STATUS" 1 && pass_test

start_test "add installs a package that is not there"
run_cmd jarvos-pkg-add mpv-mpris
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-installed" "mpv-mpris" &&
    pass_test

start_test "add on an already-installed package calls pacman not at all"
: >"$FAKE_STATE/pacman-installed"
run_cmd jarvos-pkg-add hyprland
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/pacman-installed" ]] || fail_test "pacman was called for an installed package"; } &&
    pass_test

start_test "add installs only the packages that are missing"
: >"$FAKE_STATE/pacman-installed"
run_cmd jarvos-pkg-add hyprland foot-extra
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-installed" "foot-extra" &&
    assert_not_contains "$FAKE_STATE/pacman-installed" "hyprland" &&
    pass_test

start_test "add fails loudly when pacman exits 0 without installing"
: >"$FAKE_STATE/pacman-lies"
run_cmd jarvos-pkg-add ghost-package
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "ghost-package" &&
    pass_test
rm -f "$FAKE_STATE/pacman-lies"

start_test "drop removes a package that is there"
run_cmd jarvos-pkg-drop hyprland
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/pacman-removed" "hyprland" &&
    pass_test

start_test "drop on an absent package calls pacman not at all"
: >"$FAKE_STATE/pacman-removed"
run_cmd jarvos-pkg-drop never-installed
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/pacman-removed" ]] || fail_test "pacman was called for an absent package"; } &&
    pass_test

start_test "add with no arguments is refused"
run_cmd jarvos-pkg-add
assert_status "$RUN_STATUS" 1 && pass_test

start_test "present with no argument is refused"
run_cmd jarvos-pkg-present
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-pkg"
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-pkg.test.sh && tests/jarvos-pkg.test.sh`

Expected: all cases FAIL — the commands do not exist. `jarvos-pkg: 0 passed, 12 failed`.

- [ ] **Step 4: Write `bin/jarvos-pkg-present` and `bin/jarvos-pkg-missing`**

Create `bin/jarvos-pkg-present`:

```bash
#!/usr/bin/env bash
# jarvos-pkg-present <package> — exit 0 if it is installed, 1 if it is not.
#
# The exit status IS the answer, so a migration reads as prose:
#   jarvos-pkg-present mpv || jarvos-pkg-add mpv

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -eq 1 ]] || die "usage: jarvos-pkg-present <package>"

pacman -Q "$1" >/dev/null 2>&1
```

Create `bin/jarvos-pkg-missing`:

```bash
#!/usr/bin/env bash
# jarvos-pkg-missing <package> — exit 0 if it is NOT installed.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -eq 1 ]] || die "usage: jarvos-pkg-missing <package>"

! pacman -Q "$1" >/dev/null 2>&1
```

- [ ] **Step 5: Write `bin/jarvos-pkg-add` and `bin/jarvos-pkg-drop`**

Create `bin/jarvos-pkg-add`:

```bash
#!/usr/bin/env bash
# jarvos-pkg-add <package>... — install the ones that are not already there.
#
# Verifies afterwards with pacman -Q. pacman can exit 0 having installed
# nothing (a mirror served a package that does not resolve, a hook aborted),
# and a migration that trusts that exit code marks itself applied against a
# machine that never got the package.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -gt 0 ]] || die "usage: jarvos-pkg-add <package>..."

wanted=()
for pkg in "$@"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || wanted+=("$pkg")
done

[[ ${#wanted[@]} -gt 0 ]] || exit 0

sudo pacman -S --needed --noconfirm "${wanted[@]}"

for pkg in "${wanted[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 ||
        die "pacman reported success but $pkg is not installed"
done
```

Create `bin/jarvos-pkg-drop`:

```bash
#!/usr/bin/env bash
# jarvos-pkg-drop <package>... — remove the ones that are actually there.
#
# Verifies afterwards for the same reason jarvos-pkg-add does.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

[[ $# -gt 0 ]] || die "usage: jarvos-pkg-drop <package>..."

doomed=()
for pkg in "$@"; do
    pacman -Q "$pkg" >/dev/null 2>&1 && doomed+=("$pkg")
done

[[ ${#doomed[@]} -gt 0 ]] || exit 0

sudo pacman -Rns --noconfirm "${doomed[@]}"

for pkg in "${doomed[@]}"; do
    pacman -Q "$pkg" >/dev/null 2>&1 &&
        die "pacman reported success but $pkg is still installed"
done
exit 0
```

Note the trailing `exit 0` in `jarvos-pkg-drop`: without it, `set -e` makes the script exit non-zero when the final `pacman -Q` correctly fails.

- [ ] **Step 6: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-pkg-* && tests/jarvos-pkg.test.sh`

Expected: `jarvos-pkg: 12 passed, 0 failed`, exit 0.

If the `add` cases fail because `sudo` is not shimmed, confirm `make_shims` writes a `sudo` shim that execs its arguments; the existing suite relies on one. If it does not, add:

```bash
    cat >"$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
```

- [ ] **Step 7: Run the full suite**

Run: `tests/run-all.sh`

Expected: all suites pass, `shellcheck` clean, exit 0.

- [ ] **Step 8: Commit**

```bash
git add bin/jarvos-pkg-* tests/jarvos-pkg.test.sh tests/lib/sandbox.sh
git commit -m "feat(runtime): add jarvos-pkg-{present,missing,add,drop}

The four verbs migrations are written in. add and drop act only on packages
that need it and re-verify with pacman -Q afterwards: pacman can exit 0
having installed nothing, and a migration that trusts the exit code marks
itself applied against a machine that never got the package."
```

---

## Task 3: The migration runner

**Files:**
- Create: `bin/jarvos-migrate`
- Create: `migrations/.gitkeep`
- Create: `tests/jarvos-migrate.test.sh`

**Interfaces:**
- Consumes: `lib/jarvos-common.sh` (`JARVOS_PATH`, `JARVOS_STATE`, `die`); `run_cmd` from Task 1.
- Produces: `bin/jarvos-migrate` with no-argument (run pending), `--pending` (list; exit 0 if any, 1 if none), and `--mark-all` (mark every shipped migration applied without running it) modes. Task 4 consumes `--mark-all`. Part B's `jarvos-update` consumes the no-argument form.
- Reads: `$JARVOS_PATH/migrations/*.sh`. Writes: `$JARVOS_STATE/migrations/<filename>`.
- Test seams: `JARVOS_PACMAN_LOCK` (default `/var/lib/pacman/db.lck`) and `JARVOS_LOCK_WAIT` (default `900`).

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-migrate.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-migrate — order, marker-on-success-only, replay, pre-marking, and
# deferring to a busy pacman. Run: tests/jarvos-migrate.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

MIGRATIONS="$FAKE_BASE/migrations"
MARKERS="$FAKE_HOME/.local/state/jarvos/migrations"
mkdir -p "$MIGRATIONS"

# Migrations are data, not programs: 0644 and no shebang.
migration() {
    printf '%s\n' "$2" >"$MIGRATIONS/$1.sh"
    chmod 0644 "$MIGRATIONS/$1.sh"
}

reset_world() {
    rm -rf "$MIGRATIONS" "$MARKERS"
    mkdir -p "$MIGRATIONS"
    : >"$FAKE_STATE/migration-log"
}

reset_world
migration 1700000001 'echo "first"; echo one >> "$FAKE_STATE/migration-log"'
migration 1700000002 'echo "second"; echo two >> "$FAKE_STATE/migration-log"'

start_test "--pending lists both and exits 0 when there are some"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "1700000001.sh" &&
    assert_stdout_contains "$RUN_OUT" "1700000002.sh" &&
    pass_test

start_test "a run applies them in timestamp order"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "one" &&
    [[ "$(head -1 "$FAKE_STATE/migration-log")" == "one" ]] &&
    [[ "$(tail -1 "$FAKE_STATE/migration-log")" == "two" ]] &&
    pass_test

start_test "each applied migration leaves a marker"
assert_file_exists "$MARKERS/1700000001.sh" &&
    assert_file_exists "$MARKERS/1700000002.sh" &&
    pass_test

start_test "the migration's echo reaches the user"
assert_stdout_contains "$RUN_OUT" "first" && pass_test

start_test "--pending exits 1 when nothing is pending"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a second run applies nothing"
: >"$FAKE_STATE/migration-log"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a migration ran twice"; } &&
    pass_test

start_test "deleting one marker replays exactly that migration"
: >"$FAKE_STATE/migration-log"
rm -f "$MARKERS/1700000001.sh"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "one" &&
    assert_not_contains "$FAKE_STATE/migration-log" "two" &&
    pass_test

start_test "a failing migration aborts the run and leaves no marker"
reset_world
migration 1700000010 'echo ten >> "$FAKE_STATE/migration-log"'
migration 1700000020 'echo twenty >> "$FAKE_STATE/migration-log"; exit 3'
migration 1700000030 'echo thirty >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero exit, got 0"; } &&
    assert_file_exists "$MARKERS/1700000010.sh" &&
    assert_no_file "$MARKERS/1700000020.sh" &&
    assert_not_contains "$FAKE_STATE/migration-log" "thirty" &&
    pass_test

start_test "an unset variable inside a migration is fatal, not silent"
reset_world
migration 1700000040 'echo "${definitely_not_set}" >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero exit, got 0"; } &&
    assert_no_file "$MARKERS/1700000040.sh" &&
    pass_test

start_test "the failed migration retries on the next run"
reset_world
migration 1700000050 'test -e "$FAKE_STATE/allow" || exit 1
echo fifty >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected the first run to fail"; } &&
    { : >"$FAKE_STATE/allow"; run_cmd jarvos-migrate; } &&
    assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "fifty" &&
    assert_file_exists "$MARKERS/1700000050.sh" &&
    pass_test
rm -f "$FAKE_STATE/allow"

start_test "--mark-all marks everything without running anything"
reset_world
migration 1700000060 'echo sixty >> "$FAKE_STATE/migration-log"'
migration 1700000070 'echo seventy >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate --mark-all
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$MARKERS/1700000060.sh" &&
    assert_file_exists "$MARKERS/1700000070.sh" &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "--mark-all ran a migration"; } &&
    pass_test

start_test "after --mark-all a run does nothing"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a pre-marked migration ran"; } &&
    pass_test

start_test "an empty migrations directory is not an error"
reset_world
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 && pass_test

start_test "a missing migrations directory is not an error"
rm -rf "$MIGRATIONS"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 && pass_test
mkdir -p "$MIGRATIONS"

start_test "a busy pacman defers rather than fails"
reset_world
migration 1700000080 'echo eighty >> "$FAKE_STATE/migration-log"'
: >"$FAKE_STATE/db.lck"
JARVOS_PACMAN_LOCK="$FAKE_STATE/db.lck" JARVOS_LOCK_WAIT=0 run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$MARKERS/1700000080.sh" &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "ran while pacman held the lock"; } &&
    pass_test
rm -f "$FAKE_STATE/db.lck"

start_test "an unknown argument is refused"
run_cmd jarvos-migrate --frobnicate
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-migrate"
```

Note: `JARVOS_PACMAN_LOCK=... run_cmd ...` works because `run_cmd`'s `env` inherits the caller's environment.

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-migrate.test.sh && tests/jarvos-migrate.test.sh`

Expected: all cases FAIL — `bin/jarvos-migrate` does not exist.

- [ ] **Step 3: Write `bin/jarvos-migrate`**

Create `bin/jarvos-migrate`:

```bash
#!/usr/bin/env bash
# jarvos-migrate — apply the one-time repair scripts a release ships.
#
#   jarvos-migrate             run every pending migration, in order
#   jarvos-migrate --pending   list pending ones; exit 0 if any, 1 if none
#   jarvos-migrate --mark-all  mark every shipped migration applied, run none
#
# Migrations live in $JARVOS_PATH/migrations/<unix-timestamp>.sh, mode 0644
# and with no shebang: they are data this runner interprets, never programs,
# so a stray ./ cannot fire one. The timestamp is the commit date of the
# release that introduced the migration, so lexicographic order IS
# chronological order and the glob is the whole ordering mechanism.
#
# Applied state is one empty marker per migration, per user, because every
# user on a box must get a chance at every migration.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

MARKERS="$JARVOS_STATE/migrations"
PACMAN_LOCK="${JARVOS_PACMAN_LOCK:-/var/lib/pacman/db.lck}"
LOCK_WAIT="${JARVOS_LOCK_WAIT:-900}"

pending() {
    local file
    for file in "$JARVOS_PATH"/migrations/*.sh; do
        [[ -e "$file" ]] || continue # an unmatched glob is not a migration
        [[ -e "$MARKERS/${file##*/}" ]] && continue
        printf '%s\n' "$file"
    done
}

mark_all() {
    local file
    mkdir -p "$MARKERS"
    for file in "$JARVOS_PATH"/migrations/*.sh; do
        [[ -e "$file" ]] || continue
        : >"$MARKERS/${file##*/}"
    done
}

case "${1-}" in
--pending)
    list="$(pending)"
    [[ -n "$list" ]] || exit 1
    printf '%s\n' "$list" | sed 's|.*/||'
    exit 0
    ;;
--mark-all)
    mark_all
    exit 0
    ;;
-h | --help)
    sed -n '2,20p' "$0"
    exit 0
    ;;
"") ;;
*)
    die "unknown argument: $1"
    ;;
esac

# A pacman holding the database is a deferral, not an error: the update that
# is running will call us again.
waited=0
while [[ -e "$PACMAN_LOCK" ]]; do
    if ((waited >= LOCK_WAIT)); then
        echo "jarvos-migrate: pacman is busy — deferring migrations"
        exit 0
    fi
    sleep 5
    waited=$((waited + 5))
done

mkdir -p "$MARKERS"
while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    # Strictness comes from here, which is why migrations carry no shebang.
    # set -e aborts the whole run on failure, so the marker below is only
    # ever reached on success and a failed migration retries next time.
    bash -euo pipefail "$file"
    : >"$MARKERS/${file##*/}"
done < <(pending)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-migrate && tests/jarvos-migrate.test.sh`

Expected: `jarvos-migrate: 16 passed, 0 failed`, exit 0.

- [ ] **Step 5: Keep the migrations directory in git**

```bash
mkdir -p migrations
touch migrations/.gitkeep
```

- [ ] **Step 6: Run the full suite**

Run: `tests/run-all.sh`

Expected: every suite passes, `shellcheck` clean, exit 0.

- [ ] **Step 7: Commit**

```bash
git add bin/jarvos-migrate migrations/.gitkeep tests/jarvos-migrate.test.sh
git commit -m "feat(runtime): add jarvos-migrate

One-time repair scripts for machines that already exist. Migrations are
0644 and shebang-less — data this runner interprets under bash -euo
pipefail, never programs a stray ./ can fire. The filename is the commit
timestamp of the release that introduced them, so the glob's lexicographic
order is chronological order and there is no index to keep in sync.

A marker is written only on success, so a failed migration aborts the run
and retries next invocation rather than leaving half-applied bookkeeping.
A busy pacman defers, bounded at 15 minutes, and exits 0."
```

---

## Task 4: Pre-mark shipped migrations at install time

This is the load-bearing task of the whole plan. Without it, migration N must be safe to run on a machine that never had state N−1 — a contract nobody can hold across hundreds of migrations. It must land before the first migration is ever written.

**Files:**
- Modify: `bootstrap.sh` — `deploy_dotfiles()` at line 145
- Modify: `install.sh` — around line 240, where `cp -rf config/.config/*` runs
- Create: `tests/jarvos-premark.test.sh`

**Interfaces:**
- Consumes: `bin/jarvos-migrate --mark-all` from Task 3.

- [ ] **Step 1: Write the failing test**

Create `tests/jarvos-premark.test.sh`:

```bash
#!/usr/bin/env bash
# A fresh install must pre-mark every shipped migration, so a first boot
# runs none of them. Run: tests/jarvos-premark.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

start_test "both installers invoke jarvos-migrate --mark-all"
ok=1
for f in bootstrap.sh install.sh; do
    grep -q -- '--mark-all' "$REPO_ROOT/$f" || {
        fail_test "$f never calls jarvos-migrate --mark-all"
        ok=0
        break
    }
done
[[ $ok -eq 1 ]] && pass_test

# The behaviour the installers depend on, proven against the real command
# rather than against a grep: mark everything, then confirm a run is a no-op.
MIGRATIONS="$FAKE_BASE/migrations"
mkdir -p "$MIGRATIONS"
: >"$FAKE_STATE/migration-log"
for ts in 1700000001 1700000002 1700000003; do
    printf 'echo %s >> "$FAKE_STATE/migration-log"\n' "$ts" >"$MIGRATIONS/$ts.sh"
    chmod 0644 "$MIGRATIONS/$ts.sh"
done

start_test "after pre-marking, a first boot runs zero migrations"
run_cmd jarvos-migrate --mark-all
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a shipped migration ran on a fresh install"; } &&
    pass_test

start_test "and --pending reports nothing outstanding"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-premark"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-premark.test.sh && tests/jarvos-premark.test.sh`

Expected: the first case FAILs with `bootstrap.sh never calls jarvos-migrate --mark-all`. The last two pass already — they exercise Task 3's code, and they are here to prove the property the installers rely on, not the grep.

- [ ] **Step 3: Wire it into `bootstrap.sh`**

In `bootstrap.sh`, inside `deploy_dotfiles()`, after the `run cp -rf "$base/config/.config/." "$cfg/"` line (currently line 149), add:

```bash

    # Every migration this release ships is already true of a fresh install.
    # Without this, migration N would have to be safe on a machine that never
    # had state N-1 — a contract that collapses after about fifty of them.
    step "marking shipped migrations as applied…"
    run "$base/bin/jarvos-migrate" --mark-all
```

- [ ] **Step 4: Wire it into `install.sh`**

In `install.sh`, immediately after the `cp -rf config/.config/* "$XDG_CONFIG_HOME/"` line (currently line 240), add — matching the surrounding file's style, which does not use `bootstrap.sh`'s `run`/`step` helpers:

```bash

    # A fresh install is already at the state every shipped migration
    # produces; mark them so first boot migrates nothing.
    ./bin/jarvos-migrate --mark-all
```

Verify the surrounding indentation and helper usage before pasting: if `install.sh` at that point is inside a function using its own logging helper, use it.

- [ ] **Step 5: Run the test to verify it passes**

Run: `tests/jarvos-premark.test.sh`

Expected: `jarvos-premark: 3 passed, 0 failed`, exit 0.

- [ ] **Step 6: Verify the installers still parse**

Run: `bash -n bootstrap.sh && bash -n install.sh && echo "both parse"`

Expected: `both parse`.

- [ ] **Step 7: Run the full suite**

Run: `tests/run-all.sh`

Expected: every suite passes, exit 0.

- [ ] **Step 8: Commit**

```bash
git add bootstrap.sh install.sh tests/jarvos-premark.test.sh
git commit -m "feat(install): pre-mark shipped migrations on a fresh install

A fresh install is already at the state every shipped migration produces,
so both installers now mark them applied without running them. Without
this, migration N has to be written safe against a machine that never had
state N-1, and the compatibility burden collapses the system after roughly
fifty migrations.

This lands before the first migration is written, which is the only time
it can land."
```

---

## Task 5: `jarvos-version`

**Files:**
- Create: `bin/jarvos-version`
- Create: `tests/jarvos-version.test.sh`
- Modify: `tests/lib/sandbox.sh` — teach the `pacman` shim to answer `-Q jarvos` with a version

**Interfaces:**
- Consumes: `lib/jarvos-common.sh` (`JARVOS_PATH`, `die`).
- Produces: `bin/jarvos-version`, printing either a bare version string (packaged) or `dev (<short-hash>)` (checkout). Part B's `jarvos-update` prints it at the start of a run.

There is deliberately no `VERSION` file. The package database is the oracle, so there is nothing to forget to bump.

- [ ] **Step 1: Extend the pacman shim for versioned queries**

In `tests/lib/sandbox.sh`, inside `make_shims`, change the `-Q*` branch of the `pacman` heredoc so a query for a single package prints `<name> <version>` when a version fixture exists:

```bash
    -Q*)     for p in "${@:2}"; do
                 grep -qxF "$p" "$FAKE_STATE/pacman-explicit" || exit 1
                 [[ -e "$FAKE_STATE/pacman-version-$p" ]] &&
                     printf '%s %s\n' "$p" "$(cat "$FAKE_STATE/pacman-version-$p")"
             done
             exit 0 ;;
```

- [ ] **Step 2: Write the failing test**

Create `tests/jarvos-version.test.sh`:

```bash
#!/usr/bin/env bash
# jarvos-version — the package database is the oracle; a checkout is not a
# release. Run: tests/jarvos-version.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

start_test "a git checkout reports dev with the short hash"
run_cmd jarvos-version
expected_hash="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "dev (" &&
    assert_stdout_contains "$RUN_OUT" "$expected_hash" &&
    pass_test

start_test "a packaged install reports the version pacman knows"
printf 'jarvos\n' >>"$FAKE_STATE/pacman-explicit"
printf '0.3.0-1\n' >"$FAKE_STATE/pacman-version-jarvos"
JARVOS_PATH=/usr/share/jarvos run_cmd jarvos-version
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "0.3.0-1" &&
    { [[ "$RUN_OUT" != *dev* ]] || fail_test "a packaged install must not report dev"; } &&
    pass_test

start_test "a packaged path with no jarvos package fails readably"
: >"$FAKE_STATE/pacman-explicit"
JARVOS_PATH=/usr/share/jarvos run_cmd jarvos-version
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "not installed" &&
    pass_test

summary "jarvos-version"
```

Note: the checkout case runs against the real repo, because `JARVOS_PATH` is `$FAKE_BASE` (not the packaged path) and `jarvos-version` asks git about `$JARVOS_PATH` — see Step 4's handling of a non-git `JARVOS_PATH`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `chmod +x tests/jarvos-version.test.sh && tests/jarvos-version.test.sh`

Expected: all three FAIL — `bin/jarvos-version` does not exist.

- [ ] **Step 4: Write `bin/jarvos-version`**

Create `bin/jarvos-version`:

```bash
#!/usr/bin/env bash
# jarvos-version — which JarvOS is this?
#
# The package database is the oracle, so there is no VERSION file to forget
# to bump. A git checkout is not a release and says so.

set -euo pipefail

# shellcheck source=lib/jarvos-common.sh
_lib="$(dirname "$(realpath "$0")")/../lib/jarvos-common.sh"
if [[ -r "$_lib" ]]; then source "$_lib"; else source /usr/share/jarvos/lib/jarvos-common.sh; fi
unset _lib

if [[ "$JARVOS_PATH" == "/usr/share/jarvos" ]]; then
    version="$(pacman -Q jarvos 2>/dev/null | awk '{print $2}')"
    [[ -n "$version" ]] || die "the jarvos package is not installed"
    printf '%s\n' "$version"
else
    hash="$(git -C "$JARVOS_PATH" rev-parse --short HEAD 2>/dev/null ||
        git -C "$(dirname "$(realpath "$0")")" rev-parse --short HEAD 2>/dev/null ||
        echo unknown)"
    printf 'dev (%s)\n' "$hash"
fi
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `chmod +x bin/jarvos-version && tests/jarvos-version.test.sh`

Expected: `jarvos-version: 3 passed, 0 failed`, exit 0.

- [ ] **Step 6: Verify it against the real machine**

Run: `bin/jarvos-version`

Expected: `dev (<the current short hash>)`, matching `git rev-parse --short HEAD`.

- [ ] **Step 7: Run the full suite**

Run: `tests/run-all.sh`

Expected: every suite passes, `shellcheck` clean, exit 0.

- [ ] **Step 8: Commit**

```bash
git add bin/jarvos-version tests/jarvos-version.test.sh tests/lib/sandbox.sh
git commit -m "feat(runtime): add jarvos-version

An installed machine can now answer which JarvOS it is running. The package
database is the oracle, so there is no VERSION file to forget to bump; a git
checkout is not a release and reports dev (<hash>)."
```

---

## Task 6: Cut `v0.3.0` — the first release boundary

The repo has zero tags today, so there are no release boundaries to migrate *between*. This creates the first one.

**Files:**
- Create: `CHANGELOG.md`
- Modify: `README.md` — add a short "Maintenance" section
- Modify: `CLAUDE.md` — document `migrations/` and the timestamp convention

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: git tag `v0.3.0` and the `## [Unreleased]` heading later releases append under.

- [ ] **Step 1: Write `CHANGELOG.md`**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to the JarvOS runtime. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
tags the `jarvos` package is built from.

## [Unreleased]

## [0.3.0] — 2026-08-25

The first release boundary. Before this tag there were no releases to
migrate between, so this is where the maintenance layer starts counting.

### Added

- `jarvos-version` — reports the running version. The package database is
  the oracle; a git checkout reports `dev (<hash>)`.
- `jarvos-migrate` — applies the one-time repair scripts a release ships,
  once per migration per user, in commit-timestamp order.
- `jarvos-state` — runtime markers under `$XDG_STATE_HOME/jarvos`, where the
  filename is the dispatch.
- `jarvos-pkg-present`, `jarvos-pkg-missing`, `jarvos-pkg-add`,
  `jarvos-pkg-drop` — the vocabulary migrations are written in. `add` and
  `drop` re-verify with `pacman -Q`, because pacman can exit 0 having done
  nothing.
- `tests/run-all.sh` — every suite plus `shellcheck` over the runtime scripts.

### Changed

- `bootstrap.sh` and `install.sh` mark every shipped migration applied on a
  fresh install, so a first boot migrates nothing.

### Fixed

- Notification popups no longer render their clear-all button on top of the
  topmost card's text; the button is a notification-centre action and now
  lives only there.
- The sidebar styles critical notifications correctly — it was comparing an
  enum-backed `urgency` against the string `"critical"`, which never matched.
- The network popout's settings row opens the in-shell network pane instead
  of spawning `nm-connection-editor`.
```

- [ ] **Step 2: Document the convention in `CLAUDE.md`**

In `CLAUDE.md`, add this section immediately after the `### Installer` section:

```markdown
### Maintenance layer

Runtime commands live in `bin/` and reach `$PATH` through the `jarvos`
package. They find their library through `bin/../lib/jarvos-common.sh`,
falling back to `/usr/share/jarvos/lib/jarvos-common.sh` when installed.

`migrations/<unix-timestamp>.sh` holds one-time repair scripts for machines
that already exist. The timestamp is the commit date of the release that
introduces the migration:

    git log -1 --format=%cd --date=unix

Migrations are mode `0644` with **no shebang** — the runner supplies
`bash -euo pipefail`. Write them as an `echo` of the intent, then a comment
saying why, then a guarded action in the `jarvos-pkg-*` vocabulary. The
guard is the idempotency.

Both installers call `jarvos-migrate --mark-all`, so a fresh install never
runs a shipped migration. This is what lets a migration assume the state of
the release before it.

Run `tests/run-all.sh` before committing anything under `bin/` or `lib/`.
```

- [ ] **Step 3: Add a Maintenance section to `README.md`**

Append to `README.md`:

```markdown
## Maintenance

```
jarvos-version              which JarvOS is this
jarvos-migrate --pending    what a new release wants to repair
jarvos-migrate              apply it
jarvos-state list           what the runtime has flagged
```

Migrations run once per machine per user and record themselves under
`~/.local/state/jarvos/migrations/`. Delete a marker to replay exactly that
one.
```

- [ ] **Step 4: Run the full suite one last time**

Run: `tests/run-all.sh`

Expected: every suite passes, `shellcheck` clean, exit 0.

- [ ] **Step 5: Commit and tag**

```bash
git add CHANGELOG.md README.md CLAUDE.md
git commit -m "docs: add CHANGELOG and document the maintenance layer

Cuts the first release boundary. The repo had no tags, so there were no
releases to migrate between; v0.3.0 is where the migration system starts
counting."
git tag -a v0.3.0 -m "JarvOS 0.3.0 — the maintenance layer's first release boundary"
```

- [ ] **Step 6: Verify the tag**

Run: `git tag -l && git log -1 --format=%cd --date=unix`

Expected: `v0.3.0` is listed. The second command prints the timestamp that names the **next** migration written against this release — record it in the handoff.

---

## Done when

1. `bin/jarvos-version` prints `dev (<hash>)` in the checkout. *(spec §11.1, checkout half)*
2. `tests/jarvos-premark.test.sh` proves a pre-marked install runs zero migrations. *(spec §11.2, minus the clean-VM half — that lands in Part B Task 11)*
3. `tests/jarvos-migrate.test.sh` proves a failing migration leaves no marker, aborts, and retries. *(spec §11.3)*
4. `tests/jarvos-migrate.test.sh` proves deleting one marker replays exactly that migration. *(spec §11.4)*
5. `shellcheck` passes on every new script. *(spec §11.13)*
6. `git tag -l` shows `v0.3.0`.
7. `tests/run-all.sh` exits 0.

Spec §11 items 5, 6, 7, 8, 9, 10, 11 and 12 are Part B's.

## Handoff to Part B

Record for the next plan:

- the `v0.3.0` commit timestamp from Task 6 Step 6 — it names the first real migration
- whether any pre-existing file had to be dropped from `tests/run-all.sh`'s `shellcheck` argument list
