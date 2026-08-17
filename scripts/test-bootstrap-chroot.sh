#!/usr/bin/env bash
# Simulates chroot: no user manager → bootstrap must fall back to `systemctl --global enable`,
# and must NOT reach for --global when the user manager is available.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
# fake sudo: log, drop -n, pass through to the fake systemctl
printf '#!/usr/bin/env bash\necho "sudo $*" >>"$FAKE_LOG"\n[[ "$1" == "-n" ]] && shift\nexec "$@"\n' >"$tmp/bin/sudo"
export FAKE_LOG="$tmp/log" PATH="$tmp/bin:$PATH" HOME="$tmp/home"

fail(){ echo "FAIL: $1"; [[ -f "$FAKE_LOG" ]] && cat "$FAKE_LOG"; exit 1; }

run_case(){ # $1 = exit status the fake systemctl returns for `--user`
    printf '#!/usr/bin/env bash\necho "systemctl $*" >>"$FAKE_LOG"\n[[ "$1" == "--user" ]] && exit %s\nexit 0\n' "$1" \
        >"$tmp/bin/systemctl"
    chmod +x "$tmp/bin/"*
    : >"$FAKE_LOG"
    bash -c 'source <(sed -n "/^enable_user_unit()/,/^}/p" bootstrap.sh); enable_user_unit ydotool.service' \
        || fail "enable_user_unit exited non-zero (--user status $1)"
}

# a) no user manager (chroot) → must fall back to --global
run_case 1
grep -q -- '--global enable ydotool.service' "$FAKE_LOG" || fail "no --global fallback"
# b) working user manager → must NOT touch --global
run_case 0
! grep -q -- '--global' "$FAKE_LOG" || fail "--global used even though --user succeeded"
# c) the fallback must never block on a password prompt
sed -n '/^enable_user_unit()/,/^}/p' bootstrap.sh | grep -q 'sudo -n ' \
    || fail "fallback missing 'sudo -n' (would prompt mid-bootstrap)"

grep -q 'hypr-box' bootstrap.sh || fail "hypr-box not installed by bootstrap"
grep -q 'chsoares/ezpz' bootstrap.sh && grep -q 'chsoares/ctf.fish' bootstrap.sh || fail "ezpz/ctf.fish clone missing"
grep -q 'EZPZ_HOME \$HOME/ezpz' config/.config/fish/config.fish || fail "EZPZ_HOME hardcoded"
echo PASS
