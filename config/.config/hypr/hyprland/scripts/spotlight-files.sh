#!/bin/bash
# rofi script mode for file/folder search from spotlight index
INDEX_FILE="$HOME/.cache/spotlight/index.txt"

if [ -z "$1" ]; then
    # No selection yet — output the index entries
    if [ -f "$INDEX_FILE" ]; then
        cat "$INDEX_FILE"
    fi
else
    # User selected an entry — handle it
    selection="$1"

    # Strip tag prefix
    item="${selection#\[app\] }"
    item="${item#\[file\] }"
    item="${item#\[folder\] }"

    if [ -d "$item" ]; then
        xdg-open "$item" 2>/dev/null &
    elif [ -f "$item" ]; then
        xdg-open "$item" 2>/dev/null &
    else
        $item &
    fi
fi
