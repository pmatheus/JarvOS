#!/usr/bin/env bash
# Exercise the deployed QML model without opening a desktop window.
set -euo pipefail
base=$(cd "$(dirname "$0")" && pwd)
probe=$(mktemp "$HOME/.config/quickshell/jarvos/.verify-launcher-XXXXXX.qml")
log=$(mktemp)
trap 'rm -f "$probe" "$log"' EXIT
cp "$base/probes/launcher.qml" "$probe"
timeout 8 qs -p "$probe" --no-color > "$log" 2>&1
cat "$log"
grep -q 'LIST_PROBE state=scheme values=1 count=1' "$log"
if grep -Eq 'WARN|ERROR' "$log"; then
    exit 1
fi
