#!/usr/bin/env bash
# Refresh JarvOS's snapshot of the live box: package lists, enabled services,
# groups, and tracked dotfile drift. Run from the repo root after changing the
# system, then review `git diff` before committing.
#
# This only updates the *-full snapshots and reports drift. Curated tier files
# (aur-core/apps/security, services/enable.txt) are hand-maintained — this
# script tells you what changed so you can update them deliberately.
set -euo pipefail

cd "$(dirname "$0")/.."
base="$(pwd)"
sys="$base/system"

echo "[capture] packages…"
pacman -Qqm > "$sys/packages/aur-full.txt"
pacman -Qqe > "$sys/packages/pacman-explicit-full.txt"

echo "[capture] enabled services…"
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' | sort > "$sys/services/system-enabled-full.txt"
systemctl --user list-unit-files --state=enabled --no-legend | awk '{print $1}' | sort > "$sys/services/user-enabled-full.txt"

echo "[capture] groups…"
id -Gn "$USER" | tr ' ' '\n' | sort > "$sys/groups.txt"

echo "[capture] dotfile drift (tracked config dirs live-vs-repo):"
for d in $(git ls-files config/.config | sed 's#config/.config/##; s#/.*##' | sort -u); do
    live="$HOME/.config/$d"; repo="config/.config/$d"
    [ -e "$live" ] || { echo "  MISSING-LIVE: $d"; continue; }
    diff -rq "$repo" "$live" >/dev/null 2>&1 || echo "  DRIFT: $d (run: rsync -a --delete \"$live/\" \"$repo/\" then review)"
done

echo
echo "[capture] done. New AUR pkgs not in any curated tier:"
comm -23 <(sort "$sys/packages/aur-full.txt") \
         <(cat "$sys"/packages/aur-core.txt "$sys"/packages/aur-apps.txt "$sys"/packages/aur-security.txt | grep -vE '^\s*#|^\s*$' | sort -u) \
    | sed 's/^/  + /' || true
echo "[capture] review with: git -C \"$base\" diff"
