#!/usr/bin/env bash
# A fresh install must pre-mark every shipped migration, so a first boot
# runs none of them. Run: tests/jarvos-premark.test.sh
#
# The single-quoted migration body below is written verbatim to disk:
# $FAKE_STATE has to reach the file unexpanded so the migration expands it if
# the runner ever interprets it — which is the thing this suite proves it does
# not. That is exactly what SC2016 warns about, and here it is the point.
# shellcheck disable=SC2016
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

start_test "both installers invoke jarvos-migrate --mark-all"
ok=1
for f in bootstrap.sh install.sh; do
    grep -q -- '--mark-all' "$REPO_ROOT/$f" || {
        fail_test "$f never calls jarvos-migrate --mark-all"
        ok=0
        break
    }
done
[[ $ok -eq 1 ]] && pass_test

# The behaviour the installers depend on, proven against the real command
# rather than against a grep: mark everything, then confirm a run is a no-op.
MIGRATIONS="$FAKE_BASE/migrations"
mkdir -p "$MIGRATIONS"
: >"$FAKE_STATE/migration-log"
for ts in 1700000001 1700000002 1700000003; do
    printf 'echo %s >> "$FAKE_STATE/migration-log"\n' "$ts" >"$MIGRATIONS/$ts.sh"
    chmod 0644 "$MIGRATIONS/$ts.sh"
done

start_test "after pre-marking, a first boot runs zero migrations"
run_cmd jarvos-migrate --mark-all
run_cmd jarvos-migrate
assert_status "$RUN_STATUS" 0 &&
    { [[ ! -s "$FAKE_STATE/migration-log" ]] || fail_test "a shipped migration ran on a fresh install"; } &&
    pass_test

start_test "and --pending reports nothing outstanding"
run_cmd jarvos-migrate --pending
assert_status "$RUN_STATUS" 1 && pass_test

summary "jarvos-premark"
