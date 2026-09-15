#!/usr/bin/env bash
# Wrapper for hyprlock — syncs current wallpaper to the fixed lockscreen
# path before invoking hyprlock. Idempotent: hyprlock itself refuses to
# start a second instance if one is already up.
#
# Refuses to lock while the NVIDIA kernel module and userspace driver disagree:
# hyprlock would die during GL init ("NVRM: API mismatch") and leave a black,
# unresponsive session. jarvos-gpu-ok reports the mismatch.
set -euo pipefail

if command -v jarvos-gpu-ok >/dev/null 2>&1; then
    GPU_OK="$(command -v jarvos-gpu-ok)"
elif [[ -x "$HOME/JarvOS/bin/jarvos-gpu-ok" ]]; then
    GPU_OK="$HOME/JarvOS/bin/jarvos-gpu-ok"
else
    GPU_OK=""
fi
if [[ -n "$GPU_OK" ]] && ! "$GPU_OK" 2>/dev/null; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "JarvOS" "Driver NVIDIA inconsistente apos update — reinicie antes de trancar a tela."
    fi
    printf 'NVIDIA driver mismatch; refusing to lock. Reboot first.\n' >&2
    exit 1
fi

"$HOME/.config/hypr/hyprlock/sync-wallpaper.sh" || true
exec hyprlock "$@"
