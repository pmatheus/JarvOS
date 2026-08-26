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

summary "jarvos-update-steps"
