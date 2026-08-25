#!/usr/bin/env bash
# Every test suite, then shellcheck over the maintenance-layer scripts.
# Scoped deliberately: pre-existing findings in bootstrap.sh / install.sh /
# scripts/ are not this gate's business.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0

for t in tests/*.test.sh; do
    printf '\n== %s\n' "$t"
    "$t" || fail=1
done

# The two jarvos-sync suites predate this gate and carry findings of their own;
# every other suite is in scope, including ones added later.
lint=(bin/jarvos-* lib/*.sh tests/run-all.sh tests/lib/*.sh)
for t in tests/*.test.sh; do
    [[ "$t" == *jarvos-sync-* ]] || lint+=("$t")
done

# SC1090/SC1091: every bin/jarvos-* command locates its library by a computed
# path with a packaged fallback. That indirection is the point, so shellcheck
# cannot follow it and the exclusion belongs here rather than in each command.
printf '\n== shellcheck\n'
if shellcheck -e SC1090,SC1091 "${lint[@]}"; then
    printf '  ok   no findings\n'
else
    fail=1
fi

exit "$fail"
