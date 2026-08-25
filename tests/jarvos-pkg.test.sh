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
