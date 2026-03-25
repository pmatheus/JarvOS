#!/bin/bash

# Random wallpaper selector script
# Tries to select a random wallpaper from ~/Pictures/Wallpapers/
# Falls back to the stored wallpaper path if the directory doesn't exist

WALLPAPER_DIR="$HOME/Pictures/Wallpapers/"
FALLBACK_PATH="$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"

echo "[DEBUG] Checking wallpaper directory: $WALLPAPER_DIR"

if [ -d "$WALLPAPER_DIR" ]; then
    echo "[DEBUG] Directory exists"
    ls_output=$(ls -A "$WALLPAPER_DIR" 2>/dev/null)
    if [ -n "$ls_output" ]; then
        echo "[DEBUG] Directory is not empty"
        echo "[DEBUG] Files in directory:"
        ls -la "$WALLPAPER_DIR"
        echo "[DEBUG] Running find command..."
        find_result=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \))
        echo "[DEBUG] Find result: $find_result"
        # Directory exists and is not empty, select random wallpaper
        WALLPAPER=$(echo "$find_result" | shuf -n 1)
        echo "[DEBUG] Found wallpaper: $WALLPAPER"
        
        if [ -n "$WALLPAPER" ]; then
            echo "[DEBUG] Applying wallpaper using switchwall.sh"
            # Apply the wallpaper using switchwall.sh
            "$HOME/.config/quickshell/scripts/colors/switchwall.sh" "$WALLPAPER"
            exit 0
        else
            echo "[DEBUG] No valid image files found in directory"
        fi
    else
        echo "[DEBUG] Directory is empty"
    fi
else
    echo "[DEBUG] Directory does not exist"
fi

# Fallback: use the stored wallpaper path
echo "[DEBUG] Using fallback. Checking path: $FALLBACK_PATH"
if [ -f "$FALLBACK_PATH" ]; then
    STORED_WALLPAPER=$(cat "$FALLBACK_PATH")
    echo "[DEBUG] Found stored wallpaper: $STORED_WALLPAPER"
    echo "[DEBUG] Applying fallback wallpaper with awww"
    awww img "$STORED_WALLPAPER" --transition-step 100 --transition-fps 120 --transition-type grow --transition-angle 30 --transition-duration 1
else
    echo "[DEBUG] Error: No wallpaper found and no fallback path available"
    exit 1
fi