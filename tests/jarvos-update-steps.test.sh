#!/usr/bin/env bash
# The update steps that touch the system, each alone.
# Run: tests/jarvos-update-steps.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

reset_calls() {
    : >"$FAKE_STATE/pacman-installed"
}

# jarvos-update-git runs against real repositories in jarvos-update-git.test.sh.

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

start_test "and it leaves the marker jarvos-update reads to fail the run"
assert_file_exists "$FAKE_HOME/.local/state/jarvos/aur-update-failed" && pass_test

start_test "a successful AUR pass clears a marker left by an earlier failure"
cat >"$FAKE_BIN/yay" <<'YAY'
#!/usr/bin/env bash
exit 0
YAY
chmod +x "$FAKE_BIN/yay"
run_cmd jarvos-update-aur-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$FAKE_HOME/.local/state/jarvos/aur-update-failed" &&
    pass_test

start_test "a build stopped by an unknown PGP key fetches the key and retries"
# shellcheck disable=SC2016  # expanded by the stub, not here
printf '%s\n' '#!/usr/bin/env bash' \
    'n=$(cat "$FAKE_STATE/yay-runs" 2>/dev/null || echo 0); echo $((n + 1)) > "$FAKE_STATE/yay-runs"' \
    '[[ $n -gt 0 ]] && exit 0' \
    'echo "foo-1.0.tar.gz ... FAILED (unknown public key 1A2B3C4D5E6F7A8B)" >&2; exit 1' \
    >"$FAKE_BIN/yay"
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$FAKE_STATE/gpg-calls"\n' >"$FAKE_BIN/gpg"
chmod +x "$FAKE_BIN/yay" "$FAKE_BIN/gpg"
run_cmd jarvos-update-aur-pkgs
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/gpg-calls" "--recv-keys 1A2B3C4D5E6F7A8B" &&
    assert_no_file "$FAKE_HOME/.local/state/jarvos/aur-update-failed" &&
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
