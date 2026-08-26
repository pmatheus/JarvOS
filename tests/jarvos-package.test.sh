#!/usr/bin/env bash
# The package must actually carry the runtime, and the repo must be
# distributable. Run: tests/jarvos-package.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"

PKGBUILD="$REPO_ROOT/packaging/jarvos/PKGBUILD"

start_test "a PKGBUILD exists"
assert_file_exists "$PKGBUILD" && pass_test

start_test "it parses as bash"
if bash -n "$PKGBUILD" 2>/dev/null; then
    pass_test
else
    fail_test "PKGBUILD is not valid bash"
fi

start_test "every bin/jarvos-* command is installed"
missing=""
for cmd in "$REPO_ROOT"/bin/jarvos-*; do
    grep -q "bin/" "$PKGBUILD" || missing="$missing ${cmd##*/}"
done
if grep -q 'install -Dm755 .*bin/' "$PKGBUILD"; then
    pass_test
else
    fail_test "PKGBUILD never installs bin/ with mode 755:$missing"
fi

start_test "the library lands where the fallback looks for it"
assert_contains "$PKGBUILD" "/usr/share/jarvos/lib" && pass_test

start_test "migrations are shipped 0644, as the runner requires"
assert_contains "$PKGBUILD" "644" &&
    assert_contains "$PKGBUILD" "migrations" &&
    pass_test

start_test "modules land where jarvos-module-install already looks"
assert_contains "$PKGBUILD" "/usr/share/jarvos/modules" && pass_test

start_test "a LICENSE exists — the repo is not distributable without one"
assert_file_exists "$REPO_ROOT/LICENSE" && pass_test

start_test "the PKGBUILD declares GPL3, the copyleft the shell inherits"
assert_contains "$PKGBUILD" "GPL3" && pass_test

start_test "the LICENSE is the full GPLv3, not a stub"
if [[ "$(wc -l <"$REPO_ROOT/LICENSE")" -gt 600 ]]; then
    pass_test
else
    fail_test "LICENSE is too short to be the GPLv3 text"
fi

start_test "the secret gate installs itself rather than waiting to be asked"
assert_contains "$REPO_ROOT/bootstrap.sh" "core.hooksPath" && pass_test

summary "jarvos-package"
