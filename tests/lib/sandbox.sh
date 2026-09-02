#!/usr/bin/env bash
# Shared sandbox helpers for the jarvos-sync test suite.
#
# Builds a throwaway world: a fake $HOME, a fake JarvOS baseline tree, and a
# fake $PATH of shims for pacman / systemctl / yay / dconf / sudo, so the tests
# exercise the real script without touching the real box.
#
# shellcheck shell=bash

SANDBOX_ROOT=""
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC="$REPO_ROOT/scripts/jarvos-sync"

# --- assertions ---------------------------------------------------------

start_test() {
    CURRENT_TEST="$1"
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    printf '  ok   %s\n' "$CURRENT_TEST"
}

fail_test() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL %s\n       %s\n' "$CURRENT_TEST" "$1"
}

assert_file_exists() {
    [[ -f "$1" ]] && return 0
    fail_test "expected file to exist: $1"
    return 1
}

assert_no_file() {
    [[ ! -e "$1" ]] && return 0
    fail_test "expected NOT to exist: $1"
    return 1
}

assert_contains() {
    # assert_contains <file> <fixed-string>
    grep -qF -- "$2" "$1" 2>/dev/null && return 0
    fail_test "expected '$2' in $1 (got: $(head -c 300 "$1" 2>/dev/null | tr '\n' '|'))"
    return 1
}

assert_not_contains() {
    grep -qF -- "$2" "$1" 2>/dev/null || return 0
    fail_test "did NOT expect '$2' in $1"
    return 1
}

assert_stdout_contains() {
    # assert_stdout_contains <captured-output> <fixed-string>
    [[ "$1" == *"$2"* ]] && return 0
    fail_test "expected '$2' in output: $(printf '%s' "$1" | tr '\n' '|' | head -c 400)"
    return 1
}

assert_status() {
    # assert_status <actual> <expected>
    [[ "$1" == "$2" ]] && return 0
    fail_test "expected exit $2, got $1"
    return 1
}

# Gate a tree with the very patterns the tool ships, so the test cannot drift
# from the production rules it is meant to prove.
assert_no_secret_shaped_content() {
    local dir="$1" pats hits
    pats="$(mktemp)"
    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' \
        "$REPO_ROOT/system/continuity/secret-patterns.txt" >"$pats"
    hits="$(grep -rIElf "$pats" "$dir" --exclude-dir=.git 2>/dev/null || true)"
    rm -f "$pats"
    [[ -z "$hits" ]] && return 0
    fail_test "secret-shaped content in: $hits"
    return 1
}

# --- secret-shaped fixtures ---------------------------------------------
#
# The content gate has to be fed exactly what it must refuse. But this file is
# committed to a public repo that scripts/secret-scan.sh guards, and a repo
# shipping secret-shaped literals teaches everyone to ignore the alarm. So each
# fixture is assembled from harmless parts at call time: what reaches the tool
# is byte-identical to the real thing, what sits on disk here matches nothing.

fake_openai_key()   { printf 's%s-%s' 'k' 'abcdefghijklmnopqrstuvwxyz012345'; }
fake_github_token() { printf 'gh%s_%s' 'p' 'abcdefghijklmnopqrstuvwxyz0123456789'; }
fake_aws_key()      { printf 'AK%s%s' 'IA' 'IOSFODNN7EXAMPLE'; }
fake_private_key()  { printf -- '-----%s %s PRIVATE KEY-----\n' 'BEGIN' "${1:-OPENSSH}"; }

# --- sandbox ------------------------------------------------------------

make_sandbox() {
    SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jarvos-sync-test.XXXXXX")"
    export SANDBOX_ROOT
    export FAKE_HOME="$SANDBOX_ROOT/home"
    export FAKE_BASE="$SANDBOX_ROOT/baseline"
    export FAKE_BIN="$SANDBOX_ROOT/bin"
    export FAKE_STATE="$SANDBOX_ROOT/state"
    mkdir -p "$FAKE_HOME" "$FAKE_BASE" "$FAKE_BIN" "$FAKE_STATE"

    make_baseline
    make_shims
}

clean_sandbox() {
    [[ -n "$SANDBOX_ROOT" && -d "$SANDBOX_ROOT" ]] && rm -rf "$SANDBOX_ROOT"
    SANDBOX_ROOT=""
}

# A miniature JarvOS baseline: the manifests come from the real repo (they are
# the artefact under test), the shipped dotfiles and package lists are fixtures.
make_baseline() {
    mkdir -p "$FAKE_BASE/system/packages" "$FAKE_BASE/system/services" \
        "$FAKE_BASE/config/.config/hypr/hyprland" "$FAKE_BASE/config/.config/fish" \
        "$FAKE_BASE/wallpapers"
    cp -r "$REPO_ROOT/system/continuity" "$FAKE_BASE/system/continuity"

    cat >"$FAKE_BASE/system/packages/stage1.txt" <<'EOF'
# baseline stage 1
base
linux
hyprland
kitty
fish
quickshell-git
matugen-bin
EOF
    # A v0.1 tier file that stage 1 and the modules do NOT cover. Anything only
    # listed here is no longer shipped, so it belongs in the user's delta.
    cat >"$FAKE_BASE/system/packages/aur-core.txt" <<'EOF'
quickshell-git
matugen-bin
legacy-only-pkg
EOF
    mkdir -p "$FAKE_BASE/system/modules"
    # Both shapes the real catalogue uses to install a uv tool, because the name
    # is never the literal argument of `uv tool install` in either of them.
    # Here: a loop over a continued list, exactly like security.module.
    cat >"$FAKE_BASE/system/modules/apps.module" <<'EOF'
name: Apps
description: test module
[packages]
brave-bin
zen-browser-bin
[post]
for t in demo-tool \
    looped-tool; do
    uv tool install --quiet "$t" || echo "skip uv tool $t"
done
EOF
    # And there: a local checkout installed by path, like ai.module's hypr-box.
    # Its [packages] block names a tool that is *also* installed with uv here —
    # a pacman package of the same name is not the uv tool, so it must travel.
    cat >"$FAKE_BASE/system/modules/ai.module" <<'EOF'
name: AI layer
description: test module
[packages]
sshuttle
[post]
src="${JARVOS_ROOT:-$HOME/JarvOS}/hypr-box"
uv tool install --force "$src"
EOF
    # A [post] that installs no uv tool at all, copied in shape from dev.module.
    # Every word in it — docker among them — is a word the catalogue merely
    # mentions, not a tool it installs.
    cat >"$FAKE_BASE/system/modules/dev.module" <<'EOF'
name: Dev stack
description: test module
[packages]
docker
[post]
sudo -n usermod -aG docker,libvirt "$USER" || true
echo "Log out and back in for the docker/libvirt groups to take effect."
EOF
    cat >"$FAKE_BASE/system/services/enable.txt" <<'EOF'
# scope service tier
system NetworkManager.service core
user pipewire.socket core
EOF

    printf 'source ~/.config/hypr/hyprland/general.conf\n' \
        >"$FAKE_BASE/config/.config/hypr/hyprland.conf"
    printf 'gaps_in = 5\n' >"$FAKE_BASE/config/.config/hypr/hyprland/general.conf"
    printf 'set -g fish_greeting ""\n' >"$FAKE_BASE/config/.config/fish/config.fish"
}

# PATH shims. Every one records what it was asked to do under $FAKE_STATE so
# tests can assert on real invocations rather than on mocks of our own code.
make_shims() {
    cat >"$FAKE_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    "-Qqe")  cat "$FAKE_STATE/pacman-explicit" ;;
    "-Qq")   cat "$FAKE_STATE/pacman-explicit" ;;
    "-Qqm")  cat "$FAKE_STATE/pacman-foreign" ;;
    # Above -Q*), which would otherwise swallow it and report no orphans.
    "-Qtdq") cat "$FAKE_STATE/pacman-orphans" 2>/dev/null || true ;;
    -Q*)     for p in "${@:2}"; do
                 grep -qxF "$p" "$FAKE_STATE/pacman-explicit" || exit 1
                 [[ -e "$FAKE_STATE/pacman-version-$p" ]] &&
                     printf '%s %s\n' "$p" "$(cat "$FAKE_STATE/pacman-version-$p")"
             done
             exit 0 ;;
    -Syu*)   # A full upgrade names no packages, so it must not fall through
             # to -S*) — that branch ends on a grep that finds nothing and
             # exits 1 when every argument is a flag.
             printf '%s\n' "$*" >> "$FAKE_STATE/pacman-syu-calls"
             exit 0 ;;
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

    cat >"$FAKE_BIN/yay" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/yay-installed"
printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/pacman-explicit"
EOF

    cat >"$FAKE_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
scope=system; args=()
for a in "$@"; do [[ "$a" == "--user" ]] && scope=user || args+=("$a"); done
set -- "${args[@]}"
case "${1:-}" in
    list-unit-files) cat "$FAKE_STATE/units-$scope" 2>/dev/null | sed 's/$/ enabled/' ;;
    enable)          for u in "${@:2}"; do
                         [[ "$u" == --* ]] && continue
                         grep -qxF "$u" "$FAKE_STATE/units-$scope" 2>/dev/null && continue
                         printf '%s\n' "$u" >> "$FAKE_STATE/units-$scope"
                         printf '%s %s\n' "$scope" "$u" >> "$FAKE_STATE/units-enabled-calls"
                     done ;;
    is-enabled)      grep -qxF "${2:-}" "$FAKE_STATE/units-$scope" 2>/dev/null || { echo disabled; exit 1; }
                     echo enabled ;;
    restart)         for u in "${@:2}"; do
                         [[ "$u" == --* ]] && continue
                         printf '%s\n' "$u" >> "$FAKE_STATE/units-restarted"
                     done ;;
    *)               exit 0 ;;
esac
EOF

    cat >"$FAKE_BIN/dconf" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    dump) cat "$FAKE_STATE/dconf-dump" 2>/dev/null ;;
    load) cat > "$FAKE_STATE/dconf-loaded" ;;
    *)    exit 0 ;;
esac
EOF

    cat >"$FAKE_BIN/uv" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == "tool" ]] || exit 0
case "${2:-}" in
    list) cat "$FAKE_STATE/uv-tools" 2>/dev/null ;;
    install)
        name=""
        for a in "${@:3}"; do [[ "$a" == -* ]] || name="$a"; done
        printf '%s\n' "$name" >> "$FAKE_STATE/uv-calls"
        if grep -qxF "$name" "$FAKE_STATE/uv-fail" 2>/dev/null; then
            echo "error: no solution found for $name" >&2; exit 1
        fi
        printf '%s v1.0.0\n- %s\n' "$name" "$name" >> "$FAKE_STATE/uv-tools" ;;
esac
EOF

    cat >"$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
# Drop sudo's own leading options, then exec the command with ITS options intact.
while [[ $# -gt 0 && "$1" == -* ]]; do shift; done
exec "$@"
EOF

    cat >"$FAKE_BIN/hyprctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/hyprctl-calls"
EOF

    cat >"$FAKE_BIN/journalctl" <<'EOF'
#!/usr/bin/env bash
cat "$FAKE_STATE/journal" 2>/dev/null || true
EOF

    # A git that records what it was asked and can be told to fail or to
    # leave the tree conflicted. Opt-in: the roundtrip and version suites
    # build and interrogate real repositories, so without the flag file this
    # hands straight over to the real git.
    cat >"$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
if [[ ! -e "$FAKE_STATE/git-shim" ]]; then
    PATH="${PATH#"$FAKE_BIN":}" exec git "$@"
fi
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

    chmod +x "$FAKE_BIN"/*

    printf 'base\nlinux\nhyprland\nkitty\nfish\nquickshell-git\nmatugen-bin\n' \
        >"$FAKE_STATE/pacman-explicit"
    printf 'quickshell-git\nmatugen-bin\n' >"$FAKE_STATE/pacman-foreign"
    printf 'NetworkManager.service\n' >"$FAKE_STATE/units-system"
    printf 'pipewire.socket\n' >"$FAKE_STATE/units-user"
    printf "[org/gnome/desktop/interface]\ncolor-scheme='prefer-dark'\n" >"$FAKE_STATE/dconf-dump"
    # `uv tool list` shape: a package line per tool, its executables indented
    # under it. demo-tool and looped-tool come from apps.module's [post] and
    # hypr-box from ai.module's; sshuttle is a module *package* name, and the
    # rest are the user's own. phantom-tool is an executable, never a tool.
    cat >"$FAKE_STATE/uv-tools" <<'EOF'
demo-tool v1.0.0
- demo-tool
looped-tool v1.0.0
- looped-tool
hypr-box v0.1.0
- hypr-box
sshuttle v1.3.2
- sshuttle
docker v7.1.0
- docker
user-tool v2.0.0
- user-tool
- phantom-tool
- ut
flaky-tool v0.1.0
- flaky-tool
EOF
    : >"$FAKE_STATE/uv-fail"
    : >"$FAKE_STATE/uv-calls"
}

# Run jarvos-sync inside the sandbox. Captures stdout+stderr, returns its status
# in $RUN_STATUS and its output in $RUN_OUT.
run_sync() {
    local out status
    set +e
    out="$(env \
        HOME="$FAKE_HOME" \
        PATH="$FAKE_BIN:$PATH" \
        FAKE_STATE="$FAKE_STATE" \
        JARVOS_ROOT="$FAKE_BASE" \
        JARVOS_SYNC_DIR="${JARVOS_SYNC_DIR:-$SANDBOX_ROOT/profile}" \
        JARVOS_SYNC_PROGRESS="${JARVOS_SYNC_PROGRESS:-$SANDBOX_ROOT/progress.json}" \
        "$SYNC" "$@" 2>&1)"
    status=$?
    set -e
    # shellcheck disable=SC2034  # read by the callers in the test files
    RUN_OUT="$out"
    # shellcheck disable=SC2034
    RUN_STATUS="$status"
}

# Run any bin/jarvos-* command inside the sandbox. Exported variables set by
# the caller carry through, so a test can set e.g. JARVOS_LOCK_WAIT=0 before
# calling. JARVOS_PATH points at the fake baseline so migrations and shipped
# defaults come from fixtures; the command still finds its real library via
# the bin/../lib fallback in its preamble. A caller that needs to pose as a
# packaged install overrides it the way run_sync's directories are overridden:
# JARVOS_PATH=/usr/share/jarvos run_cmd jarvos-version.
run_cmd() {
    local cmd="$1"
    shift
    local out status
    set +e
    out="$(env \
        HOME="$FAKE_HOME" \
        PATH="$FAKE_BIN:$REPO_ROOT/bin:$PATH" \
        XDG_STATE_HOME="$FAKE_HOME/.local/state" \
        FAKE_STATE="$FAKE_STATE" \
        JARVOS_PATH="${JARVOS_PATH:-$FAKE_BASE}" \
        "$REPO_ROOT/bin/$cmd" "$@" 2>&1)"
    status=$?
    set -e
    # shellcheck disable=SC2034  # read by the callers in the test files
    RUN_OUT="$out"
    # shellcheck disable=SC2034
    RUN_STATUS="$status"
}

# Same, with something on stdin. Anything that takes a secret must take it this
# way rather than as an argument — argv is readable by every process on the box
# — so the tests have to be able to feed one.
run_cmd_stdin() {
    local input="$1" cmd="$2"
    shift 2
    local out status
    set +e
    out="$(printf '%s' "$input" | env \
        HOME="$FAKE_HOME" \
        PATH="$FAKE_BIN:$REPO_ROOT/bin:$PATH" \
        XDG_STATE_HOME="$FAKE_HOME/.local/state" \
        FAKE_STATE="$FAKE_STATE" \
        JARVOS_PATH="${JARVOS_PATH:-$FAKE_BASE}" \
        "$REPO_ROOT/bin/$cmd" "$@" 2>&1)"
    status=$?
    set -e
    # shellcheck disable=SC2034
    RUN_OUT="$out"
    # shellcheck disable=SC2034
    RUN_STATUS="$status"
}

# Write a file under the fake home, creating parents.
home_file() {
    local rel="$1"
    mkdir -p "$FAKE_HOME/$(dirname "$rel")"
    cat >"$FAKE_HOME/$rel"
}

summary() {
    printf '\n%s: %d passed, %d failed\n' "${1:-tests}" "$TESTS_PASSED" "$TESTS_FAILED"
    [[ $TESTS_FAILED -eq 0 ]]
}
