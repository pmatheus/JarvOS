#!/usr/bin/env bash
# The update steps that touch the system, each alone.
# Run: tests/jarvos-update-steps.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

# Take over git for this suite: every case here asserts on what the step
# asked git to do, and none of them wants a real repository.
: >"$FAKE_STATE/git-shim"

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
if [[ "$(grep -cx 'reload' "$FAKE_STATE/hyprctl-calls")" -eq 1 ]]; then
    assert_contains "$FAKE_STATE/hyprctl-calls" "disable_autoreload 0" && pass_test
else
    fail_test "expected exactly one bare reload"
fi

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
