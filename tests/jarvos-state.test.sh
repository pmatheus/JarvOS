#!/usr/bin/env bash
# jarvos-state — markers appear, disappear, answer, list, and cannot escape
# the state directory. Run: tests/jarvos-state.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

STATE="$FAKE_HOME/.local/state/jarvos"

start_test "set creates the marker"
run_cmd jarvos-state set restart-shell-required
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$STATE/restart-shell-required" &&
    pass_test

start_test "set is idempotent"
run_cmd jarvos-state set restart-shell-required
assert_status "$RUN_STATUS" 0 && pass_test

start_test "check answers yes for a marker that exists"
run_cmd jarvos-state check restart-shell-required
assert_status "$RUN_STATUS" 0 && pass_test

start_test "check answers no for a marker that does not"
run_cmd jarvos-state check never-set
assert_status "$RUN_STATUS" 1 && pass_test

start_test "list prints the marker names, not paths"
run_cmd jarvos-state set second-marker
run_cmd jarvos-state list
assert_stdout_contains "$RUN_OUT" "restart-shell-required" &&
    assert_stdout_contains "$RUN_OUT" "second-marker" &&
    assert_not_contains <(printf '%s' "$RUN_OUT") "/" &&
    pass_test

start_test "clear removes the marker"
run_cmd jarvos-state clear restart-shell-required
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$STATE/restart-shell-required" &&
    pass_test

start_test "clear on a missing marker is not an error"
run_cmd jarvos-state clear never-set
assert_status "$RUN_STATUS" 0 && pass_test

start_test "list on an empty state dir prints nothing and exits 0"
run_cmd jarvos-state clear second-marker
run_cmd jarvos-state list
assert_status "$RUN_STATUS" 0 &&
    { [[ -z "$RUN_OUT" ]] || fail_test "expected no output, got: $RUN_OUT"; } &&
    pass_test

start_test "a name containing a slash is refused"
run_cmd jarvos-state set ../../escaped
assert_status "$RUN_STATUS" 1 &&
    assert_no_file "$FAKE_HOME/.local/escaped" &&
    assert_no_file "$FAKE_HOME/.local/state/escaped" &&
    pass_test

start_test "an empty name is refused"
run_cmd jarvos-state set ""
assert_status "$RUN_STATUS" 1 && pass_test

start_test "an unknown subcommand is refused"
run_cmd jarvos-state frobnicate thing
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-state"
