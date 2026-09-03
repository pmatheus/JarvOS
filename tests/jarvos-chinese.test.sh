#!/usr/bin/env bash
# tests/jarvos-chinese.test.sh — tests for JarvOS Chinese learning scratchpad
set -euo pipefail

# shellcheck source=tests/lib/sandbox.sh
source "$(dirname "$0")/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_PATH="$REPO_ROOT"
export PATH="$REPO_ROOT/bin:$PATH"

# --- jarvos-chinese ------------------------------------------------------

start_test "jarvos-chinese list --json returns valid JSON vocabulary"
run_cmd jarvos-chinese list --json
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" '"simplified":' &&
    assert_stdout_contains "$RUN_OUT" '"traditional":' &&
    assert_stdout_contains "$RUN_OUT" '"pinyin":' &&
    pass_test

start_test "jarvos-chinese search finds terms with character breakdown"
run_cmd jarvos-chinese search "backdoor"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "Backdoor" &&
    assert_stdout_contains "$RUN_OUT" "后门" &&
    assert_stdout_contains "$RUN_OUT" "hòu mén" &&
    assert_stdout_contains "$RUN_OUT" "Elements:" &&
    pass_test

start_test "jarvos-chinese search by hanzi finds security terms"
run_cmd jarvos-chinese search "免杀"
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "AV Evasion" &&
    assert_stdout_contains "$RUN_OUT" "miǎn shā" &&
    pass_test

start_test "jarvos-chinese mine discovers terms across agent sessions"
run_cmd jarvos-chinese mine
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "Discovered" &&
    pass_test

start_test "html scratchpad file exists and includes speech audio capability"
HTML_APP="$REPO_ROOT/share/jarvos/chinese/index.html"
assert_file_exists "$HTML_APP" &&
    grep -q "speechSynthesis" "$HTML_APP" &&
    grep -q "translate_tts" "$HTML_APP" &&
    pass_test

summary "jarvos-chinese"
