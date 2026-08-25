#!/usr/bin/env bash
# jarvos-migrate — order, marker-on-success-only, replay, pre-marking, and
# deferring to a busy pacman. Run: tests/jarvos-migrate.test.sh
#
# Every single-quoted string below is a migration body written verbatim to
# disk: $FAKE_STATE has to reach the file unexpanded so the migration expands
# it when the runner interprets it. That is exactly what SC2016 warns about,
# and here it is the point.
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

MIGRATIONS="$FAKE_BASE/migrations"
MARKERS="$FAKE_HOME/.local/state/jarvos/migrations"
mkdir -p "$MIGRATIONS"

# Migrations are data, not programs: 0644 and no shebang.
migration() {
    printf '%s\n' "$2" >"$MIGRATIONS/$1.sh"
    chmod 0644 "$MIGRATIONS/$1.sh"
}

reset_world() {
    rm -rf "$MIGRATIONS" "$MARKERS"
    mkdir -p "$MIGRATIONS"
    : >"$FAKE_STATE/migration-log"
}

reset_world
migration 1700000001 'echo "first"; echo one >> "$FAKE_STATE/migration-log"'
migration 1700000002 'echo "second"; echo two >> "$FAKE_STATE/migration-log"'

start_test "--pending lists both and exits 0 when there are some"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 0 &&
    assert_stdout_contains "$RUN_OUT" "1700000001.sh" &&
    assert_stdout_contains "$RUN_OUT" "1700000002.sh" &&
    pass_test

start_test "a run applies them in timestamp order"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "one" &&
    [[ "$(head -1 "$FAKE_STATE/migration-log")" == "one" ]] &&
    [[ "$(tail -1 "$FAKE_STATE/migration-log")" == "two" ]] &&
    pass_test

start_test "each applied migration leaves a marker"
assert_file_exists "$MARKERS/1700000001.sh" &&
    assert_file_exists "$MARKERS/1700000002.sh" &&
    pass_test

start_test "the migration's echo reaches the user"
assert_stdout_contains "$RUN_OUT" "first" && pass_test

start_test "--pending exits 1 when nothing is pending"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 1 && pass_test

start_test "a second run applies nothing"
: >"$FAKE_STATE/migration-log"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a migration ran twice"; } &&
    pass_test

start_test "deleting one marker replays exactly that migration"
: >"$FAKE_STATE/migration-log"
rm -f "$MARKERS/1700000001.sh"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "one" &&
    assert_not_contains "$FAKE_STATE/migration-log" "two" &&
    pass_test

start_test "a failing migration aborts the run and leaves no marker"
reset_world
migration 1700000010 'echo ten >> "$FAKE_STATE/migration-log"'
migration 1700000020 'echo twenty >> "$FAKE_STATE/migration-log"; exit 3'
migration 1700000030 'echo thirty >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero exit, got 0"; } &&
    assert_file_exists "$MARKERS/1700000010.sh" &&
    assert_no_file "$MARKERS/1700000020.sh" &&
    assert_not_contains "$FAKE_STATE/migration-log" "thirty" &&
    pass_test

start_test "an unset variable inside a migration is fatal, not silent"
reset_world
migration 1700000040 'echo "${definitely_not_set}" >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected non-zero exit, got 0"; } &&
    assert_no_file "$MARKERS/1700000040.sh" &&
    pass_test

start_test "the failed migration retries on the next run"
reset_world
migration 1700000050 'test -e "$FAKE_STATE/allow" || exit 1
echo fifty >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate
{ [[ "$RUN_STATUS" -ne 0 ]] || fail_test "expected the first run to fail"; } &&
    { : >"$FAKE_STATE/allow"; run_cmd jarvos-migrate; } &&
    assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "fifty" &&
    assert_file_exists "$MARKERS/1700000050.sh" &&
    pass_test
rm -f "$FAKE_STATE/allow"

start_test "--mark-all marks everything without running anything"
reset_world
migration 1700000060 'echo sixty >> "$FAKE_STATE/migration-log"'
migration 1700000070 'echo seventy >> "$FAKE_STATE/migration-log"'
run_cmd jarvos-migrate --mark-all
assert_status "$RUN_STATUS" 0 &&
    assert_file_exists "$MARKERS/1700000060.sh" &&
    assert_file_exists "$MARKERS/1700000070.sh" &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "--mark-all ran a migration"; } &&
    pass_test

start_test "after --mark-all a run does nothing"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a pre-marked migration ran"; } &&
    pass_test

start_test "an empty migrations directory is not an error"
reset_world
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 && pass_test

start_test "a missing migrations directory is not an error"
rm -rf "$MIGRATIONS"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 && pass_test
mkdir -p "$MIGRATIONS"

start_test "a busy pacman defers rather than fails"
reset_world
migration 1700000080 'echo eighty >> "$FAKE_STATE/migration-log"'
: >"$FAKE_STATE/db.lck"
JARVOS_PACMAN_LOCK="$FAKE_STATE/db.lck" JARVOS_LOCK_WAIT=0 run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_no_file "$MARKERS/1700000080.sh" &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "ran while pacman held the lock"; } &&
    pass_test
rm -f "$FAKE_STATE/db.lck"

start_test "an unknown argument is refused"
run_cmd jarvos-migrate --frobnicate
assert_status "$RUN_STATUS" 1 && pass_test

# The runner feeds the pending list to its own loop. If a migration inherits
# that as stdin and consumes it, every later migration vanishes from the loop
# unrun and unmarked, while the run still reports success.
reset_world
migration 1700000090 'cat >/dev/null; echo ninety >> "$FAKE_STATE/migration-log"'
migration 1700000091 'echo ninetyone >> "$FAKE_STATE/migration-log"'

start_test "a migration that reads stdin does not swallow the ones after it"
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    assert_contains "$FAKE_STATE/migration-log" "ninetyone" &&
    assert_file_exists "$MARKERS/1700000091.sh" &&
    pass_test

summary "jarvos-migrate"
