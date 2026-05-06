#!/usr/bin/env bash
# Time-aware greeting for hyprlock.
hour=$(date +%H)
if [ "$hour" -lt 5 ]; then
    echo "Up late"
elif [ "$hour" -lt 12 ]; then
    echo "Good morning"
elif [ "$hour" -lt 17 ]; then
    echo "Good afternoon"
elif [ "$hour" -lt 22 ]; then
    echo "Good evening"
else
    echo "Good night"
fi
