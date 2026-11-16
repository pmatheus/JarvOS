#!/usr/bin/env bash
# jarvos-update-pacnew — configuration files pacman left for a person to merge
# are listed and announced, never merged. Run: tests/jarvos-update-pacnew.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT
ROOT="$SANDBOX_ROOT/etc"
REPORT="$FAKE_HOME/.local/state/jarvos/reports/pacnew.txt"
mkdir -p "$ROOT/libvirt"

start_test "nothing to merge: says so, exits 0, leaves an empty list"
JARVOS_PACNEW_ROOT="$ROOT" run_cmd jarvos-update-pacnew
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$REPORT" &&
    { [[ ! -s "$REPORT" ]] || fail_test "list not empty: $(cat "$REPORT")"; } &&
    pass_test

start_test "pacnew and pacsave files are listed with the merge command"
: >"$ROOT/libvirt/qemu.conf.pacnew"
: >"$ROOT/pacman.conf.pacsave"
: >"$ROOT/untouched.conf"
JARVOS_PACNEW_ROOT="$ROOT" run_cmd jarvos-update-pacnew
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$REPORT" "libvirt/qemu.conf.pacnew" &&
    assert_contains "$REPORT" "pacman.conf.pacsave" &&
    assert_not_contains "$REPORT" "untouched.conf" &&
    assert_stdout_contains "$RUN_OUT" "pacdiff" &&
    pass_test

start_test "it only reports: the .pacnew is still there afterwards"
assert_file_exists "$ROOT/libvirt/qemu.conf.pacnew" && pass_test

summary "jarvos-update-pacnew"
