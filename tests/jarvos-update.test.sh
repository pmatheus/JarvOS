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
    jarvos-update-health jarvos-update-resolve jarvos-version)
stub_steps() {
    : >"$ORDER"
    rm -f "$FAKE_STATE"/fails-*
    for s in "${STEPS[@]}"; do
        printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "$FAKE_STATE/step-order"\nexit 0\n' \
            "$s" >"$FAKE_BIN/$s"
        chmod +x "$FAKE_BIN/$s"
    done
    # snapper: only `create` is the snapshot the ordering tests care about,
    # and it answers with a number the way --print-number does.
    cat >"$FAKE_BIN/snapper" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *create*) printf 'snapper\n' >> "$FAKE_STATE/step-order"; echo 42 ;;
    *)        printf 'snapper-other %s\n' "$*" >> "$FAKE_STATE/step-order" ;;
esac
EOF
    # The rollback records the snapshot it was asked to restore.
    printf '#!/usr/bin/env bash\nprintf "jarvos-update-rollback %%s\\n" "$*" >> "$FAKE_STATE/step-order"\nexit 0\n' \
        >"$FAKE_BIN/jarvos-update-rollback"
    chmod +x "$FAKE_BIN/snapper" "$FAKE_BIN/jarvos-update-rollback"
}

# fail_times <step> <n> [exit]: the step fails its first n runs, then succeeds.
fail_times() {
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s" >> "$FAKE_STATE/step-order"\nf="$FAKE_STATE/fails-%s"\nn=$(cat "$f" 2>/dev/null || echo %s)\nif [[ $n -gt 0 ]]; then echo $((n - 1)) > "$f"; exit %s; fi\nexit 0\n' \
        "$1" "$1" "$2" "${3:-1}" >"$FAKE_BIN/$1"
    chmod +x "$FAKE_BIN/$1"
}

REPORT="$FAKE_HOME/.local/state/jarvos/reports/last-update.json"
count() { grep -c "^$1\$" "$ORDER"; }
report_is() {
    # report_is <python-expression over d>
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if ($1) else 1)" "$REPORT" 2>/dev/null ||
        { fail_test "report: $(cat "$REPORT" 2>/dev/null)"; return 1; }
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

start_test "an AUR failure fails the run, but only after every other step ran"
# Non-fatal mid-pipeline, fatal at the end: the steps after AUR still get their
# turn, and the caller still learns the upgrade did not happen.
stub_steps
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "jarvos-update-aur-pkgs" >> "$FAKE_STATE/step-order"\njarvos-state set aur-update-failed\nexit 0\n' \
    >"$FAKE_BIN/jarvos-update-aur-pkgs"
chmod +x "$FAKE_BIN/jarvos-update-aur-pkgs"
JARVOS_UPDATE_TRANSCRIPT=/tmp/jarvos-update.log run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_stdout_contains "$RUN_OUT" "AUR packages were not upgraded" &&
    assert_contains "$ORDER" "jarvos-update-restart" &&
    pass_test
rm -f "$FAKE_HOME/.local/state/jarvos/aur-update-failed"

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

# --- self-repair -----------------------------------------------------------

start_test "a step the resolver fixes is re-run, and the run succeeds"
stub_steps
fail_times jarvos-update-system-pkgs 1
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(count jarvos-update-system-pkgs)" -eq 2 ]] ||
        fail_test "system-pkgs ran $(count jarvos-update-system-pkgs) times"; } &&
    assert_contains "$ORDER" "jarvos-update-resolve" &&
    assert_not_contains "$ORDER" "jarvos-update-rollback" &&
    assert_contains "$ORDER" "jarvos-migrate" &&
    pass_test

start_test "a clean run writes a report the shell can read"
report_is 'd["outcome"] == "ok" and d["problems"] == []' && pass_test

start_test "after a clean run the snapshot is handed to number cleanup"
assert_contains "$ORDER" "--cleanup-algorithm number 42" && pass_test

start_test "a step still failing after the resolver rolls back to the snapshot"
stub_steps
fail_times jarvos-update-system-pkgs 9
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_contains "$ORDER" "jarvos-update-rollback 42" &&
    assert_not_contains "$ORDER" "jarvos-migrate" &&
    assert_not_contains "$ORDER" "jarvos-update-aur-pkgs" &&
    pass_test

start_test "and the report says it was rolled back, and why"
report_is 'd["outcome"] == "rolled-back" and "system-pkgs" in d["problems"]' && pass_test

start_test "a system that would not boot after the packages is rolled back"
stub_steps
fail_times jarvos-update-health 9
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_contains "$ORDER" "jarvos-update-rollback 42" &&
    assert_not_contains "$ORDER" "jarvos-migrate" &&
    pass_test

start_test "a network failure is neither handed to the resolver nor rolled back"
stub_steps
fail_times jarvos-update-system-pkgs 9 75
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_not_contains "$ORDER" "jarvos-update-resolve" &&
    assert_not_contains "$ORDER" "jarvos-update-rollback" &&
    assert_not_contains "$ORDER" "jarvos-migrate" &&
    report_is 'd["outcome"] == "offline"' &&
    pass_test

start_test "a checkout that cannot update does not hold back the system update"
stub_steps
fail_times jarvos-update-git 9
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_contains "$ORDER" "jarvos-update-system-pkgs" &&
    assert_contains "$ORDER" "jarvos-update-restart" &&
    assert_not_contains "$ORDER" "jarvos-update-rollback" &&
    report_is 'd["outcome"] == "partial" and "git" in d["problems"]' &&
    pass_test

start_test "a failed AUR pass is handed to the resolver and tried again"
stub_steps
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "jarvos-update-aur-pkgs" >> "$FAKE_STATE/step-order"\nif [[ ! -e "$FAKE_STATE/aur-once" ]]; then : > "$FAKE_STATE/aur-once"; jarvos-state set aur-update-failed; else jarvos-state clear aur-update-failed; fi\nexit 0\n' \
    >"$FAKE_BIN/jarvos-update-aur-pkgs"
chmod +x "$FAKE_BIN/jarvos-update-aur-pkgs"
rm -f "$FAKE_STATE/aur-once"
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
assert_status "$RUN_STATUS" 0 &&
    { [[ "$(count jarvos-update-aur-pkgs)" -eq 2 ]] || fail_test "AUR ran $(count jarvos-update-aur-pkgs) times"; } &&
    pass_test

start_test "without a snapshot there is nothing to roll back to, and it says so"
stub_steps
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAKE_BIN/snapper"
fail_times jarvos-update-system-pkgs 9
JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_not_contains "$ORDER" "jarvos-update-rollback" &&
    assert_stdout_contains "$RUN_OUT" "no snapshot" &&
    report_is 'd["outcome"] == "failed"' &&
    pass_test

start_test "the resolver cannot start an update of its own"
stub_steps
JARVOS_UPDATE_RESOLVING=1 JARVOS_UPDATE_TRANSCRIPT=1 run_cmd jarvos-update -y
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero, got 0"; } &&
    assert_not_contains "$ORDER" "jarvos-update-git" &&
    pass_test

summary "jarvos-update"
