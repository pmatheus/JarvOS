#!/usr/bin/env bash
# Run INSIDE a freshly installed JarvOS VM, as the first user, before any
# manual change. Proves the things a sandbox cannot.
#
# Every check is a string because `check` evals it in the guest: the single
# quotes are the point, not an oversight, so SC2016 is off for the file.
# shellcheck disable=SC2016
set -uo pipefail

pass=0
fail=0
check() {
    if eval "$2"; then
        printf '  ok   %s\n' "$1"
        pass=$((pass + 1))
    else
        printf '  FAIL %s\n' "$1"
        fail=$((fail + 1))
    fi
}

echo "Fresh-install verification"

check "jarvos-version reports a package version, not dev" \
    '[[ "$(jarvos-version)" != *dev* ]]'

check "every shipped migration is pre-marked" \
    '! jarvos-migrate --pending'

check "a first-boot migration run applies nothing" \
    '[[ -z "$(jarvos-migrate)" ]]'

check "the runtime tooling is on PATH" \
    'command -v jarvos-update && command -v jarvos-migrate && command -v jarvos-refresh-config'

check "the library is where the packaged fallback looks" \
    '[[ -r /usr/share/jarvos/lib/jarvos-common.sh ]]'

check "the module path jarvos-module-install searches is populated" \
    '[[ -d /usr/share/jarvos/modules ]]'

check "the hook sample directories shipped" \
    '[[ -d ~/.config/jarvos/hooks/post-update.d ]]'

# The interface is discovered, never assumed: a QEMU guest under predictable
# naming has ens3, not eth0, and a failed `ip link` here would leave the
# network up and quietly turn this into a check that jarvos-update runs.
# The status is captured before the interface is restored, so restoring it
# cannot become the result being asserted.
check "jarvos-update refuses cleanly with no network" '
    iface="$(ip route show default | awk "{print \$5; exit}")"
    [[ -n "$iface" ]] || { echo "    no default route to take down"; false; }
    sudo ip link set dev "$iface" down || { echo "    could not down $iface"; false; }
    jarvos-update -y >/dev/null 2>&1
    rc=$?
    sudo ip link set dev "$iface" up
    [[ "$rc" -ne 0 ]]'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
