#!/bin/bash
# rofi script mode for spotlight
# Returns full index — rofi handles filtering as user types
INDEX_FILE="$HOME/.cache/spotlight/index.txt"

if [ "$ROFI_RETV" -eq 0 ]; then
    # Output all entries — rofi filters them as user types
    if [ -f "$INDEX_FILE" ]; then
        cat "$INDEX_FILE"
    fi
elif [ "$ROFI_RETV" -eq 1 ]; then
    selection="$1"
    item="${selection#\[app\] }"
    item="${item#\[file\] }"
    item="${item#\[folder\] }"
    tag="${selection%% *}"

    case "$tag" in
        "[app]")
            coproc (gtk-launch "$item" 2>/dev/null)
            ;;
        "[folder]"|"[file]")
            coproc (xdg-open "$item" 2>/dev/null)
            ;;
        *)
            coproc ($item 2>/dev/null)
            ;;
    esac
elif [ "$ROFI_RETV" -eq 2 ]; then
    coproc ($1 2>/dev/null)
fi
