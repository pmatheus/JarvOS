#!/bin/bash
# Spotlight launcher using rofi-wayland
# Starts clean — results adapt as you type

INDEX_FILE="$HOME/.cache/spotlight/index.txt"

pkill rofi 2>/dev/null

if [ ! -f "$INDEX_FILE" ]; then
    notify-send "Spotlight" "Index not ready yet." -t 3000
    exit 1
fi

# Prepend a non-printable marker (DEL char) to the filter so nothing matches initially.
# The user's first keystroke replaces the filter entirely, showing real results.
selection=$(cat "$INDEX_FILE" | rofi -dmenu \
    -theme ~/.config/rofi/spotlight.rasi \
    -matching normal \
    -filter $'\x7f' \
    -sorting-method fzf \
    -i)

[ -z "$selection" ] && exit 0

# Strip tag prefix
item="${selection#\[app\] }"
item="${item#\[file\] }"
item="${item#\[folder\] }"
tag="${selection%% *}"

case "$tag" in
    "[app]")
        gtk-launch "$item" 2>/dev/null &
        ;;
    "[folder]"|"[file]")
        xdg-open "$item" 2>/dev/null &
        ;;
    *)
        $item &
        ;;
esac
