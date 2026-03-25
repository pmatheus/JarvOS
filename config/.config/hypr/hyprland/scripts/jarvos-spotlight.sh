#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  JarvOS Spotlight — macOS-style launcher                    ║
# ║  Super+Space: search apps, files, folders                   ║
# ║  Enter: open | Ctrl+Enter: open in terminal                 ║
# ║  Alt+Enter: open folder in file manager                     ║
# ╚══════════════════════════════════════════════════════════════╝

INDEX_FILE="$HOME/.cache/spotlight/index.txt"
ACTION="${1:-default}"  # default, terminal, filemanager, antigravity

# Start indexer if not running
if ! pgrep -f "spotlight-indexer" >/dev/null 2>&1; then
    nohup "$HOME/.config/hypr/hyprland/scripts/spotlight-indexer.sh" &>/dev/null &
    # Wait briefly for initial index
    for i in $(seq 1 10); do
        [ -f "$INDEX_FILE" ] && break
        sleep 0.3
    done
fi

# Build index on the fly if missing
if [ ! -f "$INDEX_FILE" ]; then
    mkdir -p "$HOME/.cache/spotlight"
    # Quick apps-only index for instant response
    for dir in /usr/share/applications "$HOME/.local/share/applications"; do
        [ -d "$dir" ] && ls "$dir"/*.desktop 2>/dev/null | xargs -I{} basename {} .desktop | sed 's/^/[app] /'
    done | sort -u > "$INDEX_FILE"
fi

# Kill any existing fuzzel
pkill -x fuzzel 2>/dev/null

# Launch fuzzel in dmenu mode — centered, Spotlight style
selection=$(cat "$INDEX_FILE" | fuzzel --dmenu \
    --prompt="  " \
    --placeholder="Search apps, files, folders..." \
    --width=50 \
    --lines=12 \
    --match-mode=fzf \
    --layer=overlay \
    --output="" \
    --horizontal-pad=20 \
    --vertical-pad=12 \
    --inner-pad=8 \
    --border-width=1 \
    --border-radius=15 \
    --line-height=24 \
    --letter-spacing=0 \
    2>/dev/null)

[ -z "$selection" ] && exit 0

# Parse tag and item
tag="${selection%% *}"
item="${selection#\[app\] }"
item="${item#\[file\] }"
item="${item#\[folder\] }"

# Determine the action based on how spotlight was invoked
case "$ACTION" in
    terminal)
        # Open containing folder in terminal
        if [ -d "$item" ]; then
            kitty -1 --directory "$item" &
        elif [ -f "$item" ]; then
            kitty -1 --directory "$(dirname "$item")" &
        else
            kitty -1 &
        fi
        ;;
    filemanager)
        # Open in file manager
        if [ -d "$item" ]; then
            nautilus "$item" 2>/dev/null &
        elif [ -f "$item" ]; then
            nautilus "$(dirname "$item")" 2>/dev/null &
        fi
        ;;
    antigravity)
        # Open with antigravity
        if [ -f "$item" ]; then
            antigravity "$item" 2>/dev/null &
        elif [ -d "$item" ]; then
            antigravity "$item" 2>/dev/null &
        fi
        ;;
    *)
        # Default action: smart open
        case "$tag" in
            "[app]")
                gtk-launch "$item" 2>/dev/null &
                ;;
            "[folder]")
                nautilus "$item" 2>/dev/null || xdg-open "$item" 2>/dev/null &
                ;;
            "[file]")
                xdg-open "$item" 2>/dev/null &
                ;;
            *)
                xdg-open "$item" 2>/dev/null || $item &
                ;;
        esac
        ;;
esac
