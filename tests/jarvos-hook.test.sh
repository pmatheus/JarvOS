#!/usr/bin/env bash
# jarvos-hook — user escape hatches that can never break the caller.
# Run: tests/jarvos-hook.test.sh
#
# Every single-quoted string below is a hook body written verbatim to disk:
# $FAKE_STATE has to reach the file unexpanded so the hook expands it when
# jarvos-hook runs it. That is exactly what SC2016 warns about, and here it
# is the point.
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

HOOKS="$FAKE_HOME/.config/jarvos/hooks/post-update.d"
mkdir -p "$HOOKS"
: >"$FAKE_STATE/hook-log"

hook() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$HOOKS/$1"
    chmod +x "$HOOKS/$1"
}

start_test "an event with no hooks exits 0 quietly"
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 && pass_test

start_test "an event with no directory at all exits 0"
run_cmd jarvos-hook theme-set
assert_status "$RUN_STATUS" 0 && pass_test

start_test "hooks run in sorted order"
hook 10-first 'echo first >> "$FAKE_STATE/hook-log"'
hook 20-second 'echo second >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    [[ "$(head -1 "$FAKE_STATE/hook-log")" == "first" ]] &&
    [[ "$(tail -1 "$FAKE_STATE/hook-log")" == "second" ]] &&
    pass_test

start_test "a hook receives the event name as its first argument"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-echo-event 'echo "$1" >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_contains "$FAKE_STATE/hook-log" "post-update" && pass_test

start_test "a .sample file is never run"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-real.sample 'echo sample-ran >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/hook-log" ]] || fail_test "a .sample hook ran"; } &&
    pass_test

start_test "a non-executable file is skipped"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
printf '#!/usr/bin/env bash\necho notexec >> "$FAKE_STATE/hook-log"\n' >"$HOOKS/10-notexec"
chmod -x "$HOOKS/10-notexec"
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/hook-log" ]] || fail_test "a non-executable hook ran"; } &&
    pass_test

start_test "a failing hook reports but does not abort the rest"
: >"$FAKE_STATE/hook-log"
rm -f "$HOOKS"/*
hook 10-boom 'echo boom >> "$FAKE_STATE/hook-log"; exit 9'
hook 20-after 'echo after >> "$FAKE_STATE/hook-log"'
run_cmd jarvos-hook post-update
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/hook-log" "after" &&
    assert_stdout_contains "$RUN_OUT" "10-boom" &&
    pass_test

start_test "every shipped event directory has a sample"
missing=""
for e in post-update post-boot pre-refresh-pacman theme-set; do
    d="$REPO_ROOT/config/.config/jarvos/hooks/$e.d"
    compgen -G "$d/*.sample" >/dev/null || missing="$missing $e"
done
if [[ -z "$missing" ]]; then pass_test; else fail_test "no .sample for:$missing"; fi

start_test "no event is rejected"
run_cmd jarvos-hook
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-hook"
