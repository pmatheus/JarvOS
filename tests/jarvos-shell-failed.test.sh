#!/usr/bin/env bash
# jarvos-shell-failed and the shell unit — a crashed shell comes back, and a
# shell that keeps crashing says so instead of leaving a bare desktop.
# Run: tests/jarvos-shell-failed.test.sh
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT
UNITS="$REPO_ROOT/config/.config/systemd/user"

start_test "the shell restarts after a crash, within a start limit"
assert_contains "$UNITS/quickshell-jarvos.service" "Restart=on-failure" &&
    assert_contains "$UNITS/quickshell-jarvos.service" "StartLimitBurst=" &&
    pass_test

start_test "a restart that works does not fire the failure handler"
# Without RestartMode=direct the unit passes through "failed" on every
# restart, and OnFailure= reported a single, recovered crash as a crash loop.
assert_contains "$UNITS/quickshell-jarvos.service" "RestartMode=direct" && pass_test

start_test "a shell that gives up hands over to jarvos-shell-failed"
assert_contains "$UNITS/quickshell-jarvos.service" "OnFailure=jarvos-shell-failed.service" &&
    assert_file_exists "$UNITS/jarvos-shell-failed.service" &&
    assert_contains "$UNITS/jarvos-shell-failed.service" "jarvos-shell-failed" &&
    pass_test

start_test "jarvos-shell-failed keeps the log, notifies, and offers the diagnosis"
cat >"$FAKE_BIN/journalctl" <<'S'
#!/usr/bin/env bash
echo "qs: segfault in shell.qml (fake)"
S
cat >"$FAKE_BIN/notify-send" <<'S'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_STATE/notified"
S
chmod +x "$FAKE_BIN/journalctl" "$FAKE_BIN/notify-send"
run_cmd jarvos-shell-failed
REPORT="$FAKE_HOME/.local/state/jarvos/reports/shell-failed.log"
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$REPORT" "segfault in shell.qml" &&
    assert_contains "$FAKE_STATE/notified" "jarvos-agent-diagnose shell" &&
    pass_test

start_test "it never runs the diagnosis agent by itself"
assert_not_contains "$REPO_ROOT/bin/jarvos-shell-failed" "jarvos-agent-diagnose shell --" &&
    { ! grep -qE '^[^#]*\bjarvos-agent-diagnose\b[^"]*$' "$REPO_ROOT/bin/jarvos-shell-failed" ||
        fail_test "jarvos-shell-failed invokes the agent"; } && pass_test

summary "jarvos-shell-failed"
