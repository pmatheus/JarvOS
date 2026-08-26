#!/usr/bin/env bash
# jarvos-refresh-config — a shipped default over a user file: backup only
# when something is actually lost, and no escaping ~/.config.
# Run: tests/jarvos-refresh-config.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

export JARVOS_REFRESH_STAMP=20260825120000
SHIPPED="$FAKE_BASE/config/.config"
USERCFG="$FAKE_HOME/.config"
mkdir -p "$SHIPPED/hypr/hyprland" "$USERCFG/hypr/hyprland"

printf 'bind = SUPER, Q, killactive\n' >"$SHIPPED/hypr/hyprland/keybinds.conf"

start_test "an unmodified user file is refreshed silently, leaving no backup"
cp "$SHIPPED/hypr/hyprland/keybinds.conf" "$USERCFG/hypr/hyprland/keybinds.conf"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
assert_status "$RUN_STATUS" 0 &&
    { [[ -z "$RUN_OUT" ]] || fail_test "expected silence, got: $RUN_OUT"; } &&
    assert_no_file "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" &&
    pass_test

start_test "a modified user file is backed up and the loss is shown"
printf 'bind = SUPER, Q, exec, my-own-thing\n' >"$USERCFG/hypr/hyprland/keybinds.conf"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" &&
    assert_contains "$USERCFG/hypr/hyprland/keybinds.conf.bak.$JARVOS_REFRESH_STAMP" "my-own-thing" &&
    assert_contains "$USERCFG/hypr/hyprland/keybinds.conf" "killactive" &&
    pass_test

start_test "the report names the file, the backup, and the diff"
assert_stdout_contains "$RUN_OUT" "hypr/hyprland/keybinds.conf" &&
    assert_stdout_contains "$RUN_OUT" ".bak.$JARVOS_REFRESH_STAMP" &&
    assert_stdout_contains "$RUN_OUT" "my-own-thing" &&
    pass_test

start_test "exactly one backup, not one per run"
run_cmd jarvos-refresh-config hypr/hyprland/keybinds.conf
count="$(find "$USERCFG/hypr/hyprland" -name 'keybinds.conf.bak.*' | wc -l)"
if [[ "$count" -eq 1 ]]; then
    pass_test
else
    fail_test "expected 1 backup, found $count"
fi

start_test "a user file that does not exist yet is simply installed"
run_cmd jarvos-refresh-config hypr/hyprland/newfile.conf
assert_status "$RUN_STATUS" 1 && pass_test # no shipped default for it either
printf 'new = 1\n' >"$SHIPPED/hypr/hyprland/newfile.conf"
run_cmd jarvos-refresh-config hypr/hyprland/newfile.conf
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$USERCFG/hypr/hyprland/newfile.conf" "new = 1" &&
    assert_no_file "$USERCFG/hypr/hyprland/newfile.conf.bak.$JARVOS_REFRESH_STAMP" &&
    pass_test

start_test "a path escaping ~/.config is rejected"
run_cmd jarvos-refresh-config ../../etc/passwd
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "outside" &&
    pass_test

start_test "an absolute path is rejected"
run_cmd jarvos-refresh-config /etc/passwd
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a bare .. is rejected"
run_cmd jarvos-refresh-config hypr/../../.ssh/authorized_keys
assert_status "$RUN_STATUS" 1 &&
    assert_no_file "$FAKE_HOME/.ssh/authorized_keys" &&
    pass_test

start_test "no argument is rejected"
run_cmd jarvos-refresh-config
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a shipped default that does not exist is a readable error"
run_cmd jarvos-refresh-config hypr/nothing-ships-this.conf
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "nothing-ships-this.conf" &&
    pass_test

summary "jarvos-refresh-config"
