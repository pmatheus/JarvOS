#!/usr/bin/env bash
# jarvos-agent-sessions & jarvos-agent tests.
# Run: tests/jarvos-agent.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

RUN_DIR="$SANDBOX_ROOT/run"
mkdir -p "$RUN_DIR/jarvos/agents"
export XDG_RUNTIME_DIR="$RUN_DIR"

# --- jarvos-agent-sessions -----------------------------------------------

start_test "a live recorded session is reported in jarvos-agent-sessions"
# Use current test process PID as a live PID
my_pid=$$
cat >"$RUN_DIR/jarvos/agents/$my_pid.json" <<JSON
{"agent":"claude","pid":$my_pid,"cwd":"/home/user/test","started":"2026-09-03T12:00:00Z","task":"investigate memory leak"}
JSON

XDG_RUNTIME_DIR="$RUN_DIR" run_cmd jarvos-agent-sessions --json
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" '"agent": "claude"' &&
    assert_stdout_contains "$RUN_OUT" '"task": "investigate memory leak"' &&
    pass_test

start_test "a stale recorded session whose PID does not exist is reaped"
cat >"$RUN_DIR/jarvos/agents/9999999.json" <<'JSON'
{"agent":"codex","pid":9999999,"cwd":"/home/user/test","started":"2026-09-03T12:00:00Z","task":"old task"}
JSON

XDG_RUNTIME_DIR="$RUN_DIR" run_cmd jarvos-agent-sessions --json
assert_status "$RUN_STATUS" 0 &&
    { [[ "$RUN_OUT" != *old\ task* ]] || fail_test "stale session was not filtered out"; } &&
    assert_no_file "$RUN_DIR/jarvos/agents/9999999.json" &&
    pass_test

start_test "human-readable output formats active sessions"
XDG_RUNTIME_DIR="$RUN_DIR" run_cmd jarvos-agent-sessions
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "claude" &&
    assert_stdout_contains "$RUN_OUT" "investigate memory leak" &&
    pass_test


# --- jarvos-agent launcher -----------------------------------------------

start_test "unknown agent is rejected"
run_cmd jarvos-agent definitely-not-an-agent
assert_status "$RUN_STATUS" 1 &&
    assert_stdout_contains "$RUN_OUT" "unknown agent" &&
    pass_test

start_test "canonical names and aliases resolve correctly"
run_cmd jarvos-agent --canonical claude-code
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "claude" &&
    pass_test

run_cmd jarvos-agent --canonical agy
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "antigravity" &&
    pass_test

start_test "jarvos-agent records session and launches in terminal"
: >"$FAKE_STATE/launched"
cat >"$FAKE_BIN/kitty" <<'KEOF'
#!/usr/bin/env bash
printf 'kitty %s\n' "$*" >> "$FAKE_STATE/launched"
sleep 5 >/dev/null 2>&1 &
echo $!
KEOF
chmod +x "$FAKE_BIN/kitty"

XDG_RUNTIME_DIR="$RUN_DIR" run_cmd jarvos-agent codex --prompt "refactor auth"
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/launched" "kitty" &&
    assert_contains "$FAKE_STATE/launched" "codex" &&
    pass_test

start_test "the session file was created with the prompt as task"
count=$(find "$RUN_DIR/jarvos/agents" -name "*.json" | wc -l)
if [[ "$count" -ge 1 ]]; then
    sess_file=$(find "$RUN_DIR/jarvos/agents" -name "*.json" | head -n 1)
    assert_contains "$sess_file" "refactor auth" && pass_test
else
    fail_test "no session file created"
fi
# --- jarvos-agent-pick ---------------------------------------------------

start_test "jarvos-agent-pick --list prints every agent with session status"
run_cmd jarvos-agent-pick --list
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "claude" &&
    assert_stdout_contains "$RUN_OUT" "codex" &&
    assert_stdout_contains "$RUN_OUT" "opencode" &&
    assert_stdout_contains "$RUN_OUT" "antigravity" &&
    pass_test

start_test "keybinds.conf routes Super+A through jarvos-agent-pick"
assert_contains "$REPO_ROOT/config/.config/hypr/hyprland/keybinds.conf" "jarvos-agent-pick" && pass_test

# --- failure handoff -----------------------------------------------------

start_test "an update diagnosis names the transcript and the skill"
printf 'error: something broke\n' >"$FAKE_STATE/fake-update.log"
JARVOS_UPDATE_TRANSCRIPT="$FAKE_STATE/fake-update.log" \
    run_cmd jarvos-agent-diagnose update --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "something broke" &&
    assert_stdout_contains "$RUN_OUT" "SKILL.md" &&
    pass_test

start_test "--dry-run prints the prompt and launches nothing"
: >"$FAKE_STATE/launched"
JARVOS_UPDATE_TRANSCRIPT="$FAKE_STATE/fake-update.log" \
    run_cmd jarvos-agent-diagnose update --dry-run
{ [[ ! -s "$FAKE_STATE/launched" ]] || fail_test "--dry-run launched an agent"; } && pass_test

start_test "an unknown kind is refused"
run_cmd jarvos-agent-diagnose frobnicate
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a crash diagnosis carries the process facts"
run_cmd jarvos-agent-diagnose crash 1234 kitty /usr/bin/kitty SIGSEGV --dry-run
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "1234" &&
    assert_stdout_contains "$RUN_OUT" "SIGSEGV" &&
    pass_test

start_test "the shipped skill exists where the prompt points"
assert_file_exists "$REPO_ROOT/config/.config/jarvos/agents/skills/diagnose-failure/SKILL.md" &&
    pass_test

start_test "jarvos-update offers the diagnosis without running it"
assert_contains "$REPO_ROOT/bin/jarvos-update" "jarvos-agent-diagnose" && pass_test

# --- usage tracking and session focus ------------------------------------

start_test "jarvos-agent-sessions --full returns sessions and providers"
run_cmd jarvos-agent-sessions --full
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" '"sessions":' &&
    assert_stdout_contains "$RUN_OUT" '"providers":' &&
    pass_test

start_test "jarvos-agent-focus requires a pid argument"
run_cmd jarvos-agent-focus
assert_status "$RUN_STATUS" 1 && pass_test

start_test "jarvos-agent-usage-update runs collectors and outputs json records"
run_cmd jarvos-agent-usage-update
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$HOME/.local/state/jarvos/agents/usage/claude.json" &&
    assert_file_exists "$HOME/.local/state/jarvos/agents/usage/codex.json" &&
    assert_file_exists "$HOME/.local/state/jarvos/agents/usage/antigravity.json" &&
    assert_file_exists "$HOME/.local/state/jarvos/agents/usage/opencode.json" &&
    pass_test


start_test "jarvos-agent-monitor streams initial json state and reacts"
first_line=$(timeout 2 jarvos-agent-monitor 2>/dev/null | head -n 1 || true)
{ [[ -n "$first_line" ]] && jq -e . >/dev/null 2>&1 <<<"$first_line"; } && pass_test

summary "jarvos-agent"
