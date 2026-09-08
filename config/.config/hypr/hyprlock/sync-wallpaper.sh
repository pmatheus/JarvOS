#!/usr/bin/env bash
# Resolve the current Omarchy wallpaper (or legacy awww) and symlink it to a fixed
# path that hyprlock.conf references. Run before each hyprlock invocation.
set -euo pipefail

target="$HOME/.cache/hyprlock-wallpaper"
fallback="/home/user/hyper-arch/wallpapers/996764.jpg"

src=""
if [[ -f "$HOME/.local/state/omarchy/current/background" ]]; then
    src=$(readlink -f "$HOME/.local/state/omarchy/current/background")
fi
if [[ -z "$src" ]] && command -v awww >/dev/null 2>&1; then
    src=$(awww query 2>/dev/null \
        | head -1 \
        | sed -nE 's/.*currently displaying: image: (.+)$/\1/p')
fi

if [ -z "$src" ] || [ ! -f "$src" ]; then
    src="$fallback"
fi

ln -sfn "$src" "$target"
