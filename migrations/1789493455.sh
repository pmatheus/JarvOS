echo "Porting custom Hyprland monitor overrides to the Lua config"

# Hyprland 0.56 loads hyprland.lua in preference to hyprland.conf and drops
# .conf support in 0.57, so JarvOS ships a Lua config. A machine that kept its
# monitor layout in hyprland/custom/monitors.conf would silently lose it: the
# Lua entry point requires custom/*.lua and never reads .conf. Convert the
# monitor and workspace lines mechanically; anything else in the file is left
# for the user, with the original kept beside the result.
#
# The guard is the idempotency: an existing monitors.lua is never overwritten.

conf="$HOME/.config/hypr/hyprland/custom/monitors.conf"
lua="$HOME/.config/hypr/hyprland/custom/monitors.lua"

if [[ -f "$conf" && ! -e "$lua" ]]; then
    {
        echo "-- Ported from monitors.conf by a JarvOS migration."
        echo "-- The original is kept beside this file; delete it once this looks right."
        echo

        # monitor = NAME, MODE, POSITION, SCALE[, extra...]
        grep -E '^[[:space:]]*monitor[[:space:]]*=' "$conf" \
        | sed -E 's/^[[:space:]]*monitor[[:space:]]*=[[:space:]]*//; s/[[:space:]]*#.*$//' \
        | awk -F'[[:space:]]*,[[:space:]]*' 'NF >= 4 {
            printf "hl.monitor({ output = \"%s\", mode = \"%s\", position = \"%s\", scale = %s })\n", $1, $2, $3, $4
          }'

        echo

        # workspace = N, monitor:NAME
        grep -E '^[[:space:]]*workspace[[:space:]]*=' "$conf" \
        | sed -E 's/^[[:space:]]*workspace[[:space:]]*=[[:space:]]*//; s/[[:space:]]*#.*$//' \
        | awk -F'[[:space:]]*,[[:space:]]*' '$2 ~ /^monitor:/ {
            sub(/^monitor:/, "", $2)
            printf "hl.workspace_rule({ workspace = \"%s\", monitor = \"%s\" })\n", $1, $2
          }'
    } > "$lua"

    echo "  wrote ${lua/#$HOME/\~}"
fi
