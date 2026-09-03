#!/usr/bin/env bash
# tests/jarvos-hunt.test.sh — tests for JarvOS threat hunting and case tooling
set -euo pipefail

# shellcheck source=tests/lib/sandbox.sh
source "$(dirname "$0")/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_PATH="$REPO_ROOT"
export PATH="$REPO_ROOT/bin:$PATH"

FAKE_CASES="$SANDBOX_ROOT/cases"
mkdir -p "$FAKE_CASES/case-alpha" "$FAKE_CASES/case-beta"
export JARVOS_CASES_DIR="$FAKE_CASES"

# --- jarvos-case ---------------------------------------------------------

start_test "jarvos-case list finds cases in configured cases dir"
run_cmd jarvos-case list --json
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "case-alpha" &&
    assert_stdout_contains "$RUN_OUT" "case-beta" &&
    pass_test

start_test "jarvos-case select sets active case"
run_cmd jarvos-case select case-alpha
assert_status "$RUN_STATUS" 0 && pass_test

start_test "jarvos-case active reports selected case"
run_cmd jarvos-case active
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "case-alpha" &&
    pass_test

start_test "jarvos-case active --path reports full directory"
run_cmd jarvos-case active --path
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "$FAKE_CASES/case-alpha" &&
    pass_test

start_test "jarvos-case new scaffolds standard directory structure"
run_cmd jarvos-case new incident-test
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$FAKE_CASES/incident-test/CASE.md" &&
    { [[ -d "$FAKE_CASES/incident-test/artifacts" ]] || fail_test "artifacts dir missing"; } &&
    { [[ -d "$FAKE_CASES/incident-test/evidence/triage" ]] || fail_test "evidence/triage dir missing"; } &&
    { [[ -d "$FAKE_CASES/incident-test/hunt" ]] || fail_test "hunt dir missing"; } &&
    { [[ -d "$FAKE_CASES/incident-test/iocs" ]] || fail_test "iocs dir missing"; } &&
    { [[ -d "$FAKE_CASES/incident-test/reports" ]] || fail_test "reports dir missing"; } &&
    pass_test

# --- jarvos-hunt-triage --------------------------------------------------

start_test "jarvos-hunt-triage --dry-run completes without error"
run_cmd jarvos-hunt-triage --dry-run --case incident-test
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "TRIAGE DRY-RUN" &&
    pass_test

# --- jarvos-hunt-ioc -----------------------------------------------------

start_test "jarvos-hunt-ioc defangs IP addresses and URLs safely"
run_cmd jarvos-hunt-ioc defang "http://evil.com?c2=10.20.30.40"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "hxxp://evil[.]com?c2=10[.]20[.]30[.]40" &&
    pass_test

start_test "jarvos-hunt-ioc refang reverses defanging"
run_cmd jarvos-hunt-ioc refang "hxxp://evil[.]com?c2=10[.]20[.]30[.]40"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "http://evil.com?c2=10.20.30.40" &&
    pass_test

start_test "jarvos-hunt-ioc extract identifies IP and hash"
sample_file="$SANDBOX_ROOT/sample_ioc.txt"
printf "Connecting to 198.51.100.22 with hash e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\n" > "$sample_file"
run_cmd jarvos-hunt-ioc extract "$sample_file"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "198.51.100.22" &&
    assert_stdout_contains "$RUN_OUT" "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" &&
    pass_test

# --- agent diagnosis handoff ---------------------------------------------

start_test "jarvos-agent-diagnose hunt gathers case facts and prompt"
run_cmd jarvos-agent-diagnose hunt incident-test --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "incident-test" &&
    assert_stdout_contains "$RUN_OUT" "threat hunting" &&
    pass_test

summary "jarvos-hunt"
