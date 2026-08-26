#!/usr/bin/env bash
# jarvos-update — ordering, exclusion, gating, resumability.
# Run: tests/jarvos-update.test.sh
#
# The single-quoted strings below are stub bodies written verbatim to disk:
# $FAKE_STATE has to reach the file unexpanded so the stub expands it when
# jarvos-update runs it. That is what SC2016 warns about, and here it is the
# point.
# shellcheck disable=SC2016
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
{ [[ "$(pos jarvos-update-git)" -lt "$(pos jarvos-update-system-pkgs)" ]] ||
    fail_test "git ran after packages"; } && pass_test

start_test "the keyring is refreshed before the main transaction"
{ [[ "$(pos jarvos-update-keyring)" -lt "$(pos jarvos-update-system-pkgs)" ]] ||
    fail_test "keyring ran after packages"; } && pass_test

start_test "migrations run after packages, against what was just installed"
{ [[ "$(pos jarvos-migrate)" -gt "$(pos jarvos-update-system-pkgs)" ]] ||
    fail_test "migrations ran before packages"; } && pass_test

start_test "AUR runs after migrations, so a bad build cannot strand them"
{ [[ "$(pos jarvos-update-aur-pkgs)" -gt "$(pos jarvos-migrate)" ]] ||
    fail_test "AUR ran before migrations"; } && pass_test

start_test "the snapshot is taken before anything mutates the system"
{ [[ "$(pos snapper)" -lt "$(pos jarvos-update-git)" ]] ||
    fail_test "snapshot taken after mutation began"; } && pass_test

start_test "post-update hooks fire after migrations"
{ [[ "$(pos jarvos-hook)" -gt "$(pos jarvos-migrate)" ]] ||
    fail_test "hooks fired before migrations"; } && pass_test

start_test "the sleep inhibitor neither strands the lock nor repeats the body"
# systemd-inhibit closes every descriptor above 2 in the command it runs
# while keeping the inherited copy itself. A lock taken before that re-exec
# is therefore held by a process that is no longer us, and the re-exec'd
# shell waits on it forever — so the timeout here is what turns a hang into
# a failure. Running once, not once per re-exec, is the other half: the
# snapshot is a system mutation and must not be taken twice.
stub_steps
inhibit_out="$(env HOME="$FAKE_HOME" PATH="$FAKE_BIN:$REPO_ROOT/bin:$PATH" \
    XDG_STATE_HOME="$FAKE_HOME/.local/state" FAKE_STATE="$FAKE_STATE" \
    JARVOS_PATH="$FAKE_BASE" JARVOS_UPDATE_TRANSCRIPT=1 \
    timeout 30 "$REPO_ROOT/bin/jarvos-update" -y 2>&1)"
inhibit_status=$?
{ [[ "$inhibit_status" -ne 124 ]] ||
    fail_test "the run hung: $inhibit_out"; } &&
    assert_status "$inhibit_status" 0 &&
    { [[ "$(grep -c '^snapper$' "$ORDER")" -eq 1 ]] ||
        fail_test "snapper ran $(grep -c '^snapper$' "$ORDER") times, expected once"; } &&
    { [[ "$(grep -c '^jarvos-version$' "$ORDER")" -eq 2 ]] ||
        fail_test "the body ran $(($(grep -c '^jarvos-version$' "$ORDER") / 2)) times, expected once"; } &&
    pass_test

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
(JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y) &
first=$!
sleep 0.3
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
second_status="$RUN_STATUS"
wait "$first"
# Either the second waited (both ran, cleanly nested) or it declined. What
# it must never do is start its own package step inside the first's.
interleaved=0
awk '/^enter$/{d++} /^leave$/{d--} d>1{exit 1}' "$ORDER" || interleaved=1
{ [[ "$interleaved" -eq 0 ]] ||
    fail_test "a second run interleaved with the first (status $second_status)"; } && pass_test

summary "jarvos-update"
