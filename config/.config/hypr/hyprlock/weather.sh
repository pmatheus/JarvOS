#!/usr/bin/env bash
# Compact local weather. Cached 30 min so hyprlock doesn't hammer wttr.in.
set -euo pipefail
cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-weather"
ttl=1800

if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
    if [ "$age" -lt "$ttl" ]; then
        cat "$cache"
        exit 0
    fi
fi

result=$(curl -fsSL --max-time 3 "https://wttr.in/?format=%c+%t" 2>/dev/null | tr -d ' ' || true)
if [ -z "$result" ]; then
    [ -f "$cache" ] && cat "$cache" || echo ""
    exit 0
fi

printf '%s' "$result" > "$cache"
printf '%s' "$result"
