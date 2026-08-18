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
    cat >"$FAKE_BASE/system/modules/apps.module" <<'EOF'
name: Apps
description: test module
[packages]
brave-bin
zen-browser-bin
[post]
echo hi
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
    -Q*)     for p in "${@:2}"; do grep -qxF "$p" "$FAKE_STATE/pacman-explicit" || exit 1; done ;;
    -S*)     printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/pacman-installed"
             printf '%s\n' "${@:2}" | grep -v '^--' >> "$FAKE_STATE/pacman-explicit" ;;
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

    cat >"$FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
# Drop sudo's own leading options, then exec the command with ITS options intact.
while [[ $# -gt 0 && "$1" == -* ]]; do shift; done
exec "$@"
EOF

    chmod +x "$FAKE_BIN"/*

    printf 'base\nlinux\nhyprland\nkitty\nfish\nquickshell-git\nmatugen-bin\n' \
        >"$FAKE_STATE/pacman-explicit"
    printf 'quickshell-git\nmatugen-bin\n' >"$FAKE_STATE/pacman-foreign"
    printf 'NetworkManager.service\n' >"$FAKE_STATE/units-system"
    printf 'pipewire.socket\n' >"$FAKE_STATE/units-user"
    printf "[org/gnome/desktop/interface]\ncolor-scheme='prefer-dark'\n" >"$FAKE_STATE/dconf-dump"
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
