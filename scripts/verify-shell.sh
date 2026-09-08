#!/usr/bin/env bash
# Verify the shell end to end: the repo test gate, then the live shell —
# service health, QML log cleanliness, deployed-copy sync, live watchers —
# and finally the checks that need human eyes. Exit 0 only if every
# automated check passes.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "== repo gate"
if tests/run-all.sh; then
    ok "tests/run-all.sh (bash suites + QML runner + shellcheck)"
else
    bad "tests/run-all.sh — see output above"
fi

echo "== live shell"
if systemctl --user is-active quickshell-jarvos.service >/dev/null 2>&1; then
    ok "quickshell-jarvos.service active"
else
    bad "quickshell-jarvos.service not active"
fi

LOG=$(timeout 5 qs log -p "$HOME/.config/quickshell/jarvos/shell.qml" 2>&1)
if ! bin/jarvos-shell status >/dev/null 2>&1; then
    bad "native JarvOS IPC unavailable"
else
    ok "native JarvOS IPC responding"
fi
QML_ERRS=$(printf '%s\n' "$LOG" | grep -E 'WARN|ERROR' | grep -cE 'QML|Unable to assign|TypeError|ReferenceError|is not a function|\.qml' || true)
DBUS_ERRS=$(printf '%s\n' "$LOG" | grep -ciE 'dbus|StatusNotifier' || true)
if [ "$QML_ERRS" -eq 0 ]; then
    ok "no QML errors in the current session log"
else
    bad "$QML_ERRS QML errors/warnings — inspect with: qs log -p ~/.config/quickshell/jarvos/shell.qml"
fi
if [ "$DBUS_ERRS" -gt 0 ]; then
    printf '  info %s external dbus/tray warnings (not QML — a tray app misbehaving)\n' "$DBUS_ERRS"
fi

if diff -rq config/.config/quickshell/jarvos "$HOME/.config/quickshell/jarvos" >/dev/null 2>&1; then
    ok "deployed copy in sync with the repo"
else
    bad "deployed copy differs from the repo (cp -rf config/.config/quickshell/jarvos/. ~/.config/quickshell/jarvos/)"
fi

if pgrep -f "inotifywait.*Wallpapers" >/dev/null 2>&1; then
    ok "wallpaper directory watcher armed"
else
    bad "no inotifywait watching Wallpapers — new wallpapers would not appear live"
fi

if rg -n 'import Caelestia|\["caelestia",' config/.config/quickshell/jarvos -g '*.qml'; then
    bad "Caelestia executable or plugin dependency remains"
else
    ok "no Caelestia executable or QML plugin dependencies"
fi

echo "== live-change drill"
WALLS="$HOME/Pictures/Wallpapers"
if [ -d "$WALLS" ]; then
    touch "$WALLS/.jarvos-verify.tmp"
    sleep 1
    if pgrep -f "inotifywait.*Wallpapers" >/dev/null 2>&1; then
        ok "watcher survived a create/delete event cycle"
    else
        bad "watcher died after an event"
    fi
    rm -f "$WALLS/.jarvos-verify.tmp"
else
    bad "$WALLS missing — cannot drill the wallpaper watcher"
fi

echo "== needs your eyes"
cat <<'EOF'
  - bar network chip popout: two lines (upload/download) with soft fill
  - dashboard performance card: graph slides in smoothly on each sample
  - launcher wallpapers: grid populates; clicking applies a wallpaper
  - utilities recordings list: recording_*.mp4 entries, newest first
  - file dialog: browses and enters directories
  - toasts: toggle game mode -> toast appears, holds while its exit
    animation runs, then disappears
EOF

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
