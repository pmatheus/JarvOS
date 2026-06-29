#!/usr/bin/env bash
# Wrapper for hyprlock — syncs current wallpaper to the fixed lockscreen
# path before invoking hyprlock. Idempotent: hyprlock itself refuses to
# start a second instance if one is already up.
set -euo pipefail

"$HOME/.config/hypr/hyprlock/sync-wallpaper.sh" || true
exec hyprlock "$@"
