#!/usr/bin/env bash
# Resolve the current desktop wallpaper from awww and symlink it to a fixed
# path that hyprlock.conf references. Run before each hyprlock invocation.
set -euo pipefail

target="$HOME/.cache/hyprlock-wallpaper"
fallback="/home/user/hyper-arch/wallpapers/996764.jpg"

src=""
if command -v awww >/dev/null 2>&1; then
    src=$(awww query 2>/dev/null \
        | head -1 \
        | sed -nE 's/.*currently displaying: image: (.+)$/\1/p')
fi

if [ -z "$src" ] || [ ! -f "$src" ]; then
    src="$fallback"
fi

ln -sfn "$src" "$target"
