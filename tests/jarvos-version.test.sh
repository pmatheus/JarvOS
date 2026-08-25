#!/usr/bin/env bash
# jarvos-version — the package database is the oracle; a checkout is not a
# release. Run: tests/jarvos-version.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

start_test "a git checkout reports dev with the short hash"
run_cmd jarvos-version
expected_hash="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "dev (" &&
    assert_stdout_contains "$RUN_OUT" "$expected_hash" &&
    pass_test

start_test "a packaged install reports the version pacman knows"
printf 'jarvos\n' >>"$FAKE_STATE/pacman-explicit"
printf '0.3.0-1\n' >"$FAKE_STATE/pacman-version-jarvos"
JARVOS_PATH=/usr/share/jarvos run_cmd jarvos-version
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "0.3.0-1" &&
    { [[ "$RUN_OUT" != *dev* ]] || fail_test "a packaged install must not report dev"; } &&
    pass_test

start_test "a packaged path with no jarvos package fails readably"
: >"$FAKE_STATE/pacman-explicit"
JARVOS_PATH=/usr/share/jarvos run_cmd jarvos-version
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "not installed" &&
    pass_test

summary "jarvos-version"
