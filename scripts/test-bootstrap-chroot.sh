#!/usr/bin/env bash
# Simulates chroot: no user manager → bootstrap must fall back to `systemctl --global enable`.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$FAKE_LOG"
[[ "$1" == "--user" ]] && { echo "Failed to connect to bus" >&2; exit 1; }
exit 0
EOF
for c in sudo yay pacman git uv; do printf '#!/usr/bin/env bash\necho "%s $*" >>"$FAKE_LOG"\n' "$c" >"$tmp/bin/$c"; done
# sudo must pass through to the fake systemctl
printf '#!/usr/bin/env bash\necho "sudo $*" >>"$FAKE_LOG"; exec "$@"\n' >"$tmp/bin/sudo"
chmod +x "$tmp/bin/"*
export FAKE_LOG="$tmp/log" PATH="$tmp/bin:$PATH" HOME="$tmp/home"
mkdir -p "$HOME"
: >"$FAKE_LOG"
bash -c 'source <(sed -n "/^enable_user_unit()/,/^}/p" bootstrap.sh); enable_user_unit ydotool.service'
grep -q -- '--global enable ydotool.service' "$FAKE_LOG" || { echo "FAIL: no --global fallback"; cat "$FAKE_LOG"; exit 1; }
grep -q 'hypr-box' bootstrap.sh || { echo "FAIL: hypr-box not installed by bootstrap"; exit 1; }
grep -q 'chsoares/ezpz' bootstrap.sh && grep -q 'chsoares/ctf.fish' bootstrap.sh || { echo "FAIL: ezpz/ctf.fish clone missing"; exit 1; }
grep -q 'EZPZ_HOME \$HOME/ezpz' config/.config/fish/config.fish || { echo "FAIL: EZPZ_HOME hardcoded"; exit 1; }
echo PASS
