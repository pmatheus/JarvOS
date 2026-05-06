#!/usr/bin/env bash
# Minimal system status line for hyprlock — host + uptime.
host=$(hostname)
uptime=$(uptime -p | sed 's/^up //')
printf '%s · up %s' "$host" "$uptime"
