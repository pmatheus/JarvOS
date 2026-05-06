#!/usr/bin/env bash
set -euo pipefail

PATH_LOCK="$HOME/.config/quickshell/jarvos/lock-shell.qml"

if qs ipc -p "$PATH_LOCK" call lock lock 2>/dev/null; then
    exit 0
fi

systemctl --user start quickshell-jarvos-lock.service

for _ in $(seq 1 30); do
    sleep 0.1
    if qs ipc -p "$PATH_LOCK" call lock lock 2>/dev/null; then
        exit 0
    fi
done

echo "jarvos-lock: failed to reach lock instance" >&2
exit 1
