#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

# Troca os valores de $term1 e $term2
idx1=-1
idx2=-1
for i in "${!colorlist[@]}"; do
    [[ "${colorlist[$i]}" == "\$term2" ]] && idx1=$i
    [[ "${colorlist[$i]}" == "\$term3" ]] && idx2=$i
done

if [[ $idx1 -ge 0 && $idx2 -ge 0 ]]; then
    tmp="${colorvalues[$idx1]}"
    colorvalues[$idx1]="${colorvalues[$idx2]}"
    colorvalues[$idx2]="$tmp"
fi

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$CONFIG_DIR"/scripts/terminal/sequences.txt ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$CONFIG_DIR"/scripts/terminal/sequences.txt "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

# Function to enhance color for RGB lighting using Python for accurate HSV conversion
enhance_for_rgb() {
  local hex_color="$1"
  
  # Remove # if present
  hex_color="${hex_color#\#}"
  
  # Use Python for accurate HSV conversion and manipulation
  python3 -c "
import colorsys

# Convert hex to RGB (0-1 range)
hex_color = '$hex_color'
r = int(hex_color[0:2], 16) / 255.0
g = int(hex_color[2:4], 16) / 255.0  
b = int(hex_color[4:6], 16) / 255.0

# Convert RGB to HSV
h, s, v = colorsys.rgb_to_hsv(r, g, b)

# Convert hue to degrees
h_degrees = h * 360

# Set saturation and value to maximum
s = 1.0
v = 1.0

# Convert back to RGB
r_new, g_new, b_new = colorsys.hsv_to_rgb(h, s, v)

# Convert to 0-255 range and format as hex
r_int = int(r_new * 255)
g_int = int(g_new * 255)
b_int = int(b_new * 255)

print(f'{r_int:02x}{g_int:02x}{b_int:02x}')
"
}

apply_qt() {
  sh "$CONFIG_DIR/scripts/kvantum/materialQT.sh"          # generate kvantum theme
  python "$CONFIG_DIR/scripts/kvantum/changeAdwColors.py" # apply config colors
}

apply_openrgb() {
  # Find primary color value for OpenRGB (main color from wallpaper)
  primary_color=""
  for i in "${!colorlist[@]}"; do
    if [[ "${colorlist[$i]}" == "\$primary_paletteKeyColor" ]]; then
      primary_color="${colorvalues[$i]#\#}"  # Remove # if present
      break
    fi
  done
  
  if [ -n "$primary_color" ]; then
    # Enhance primary color for RGB lighting (max saturation/value, maps yellow/orange to red)
    enhanced_color=$(enhance_for_rgb "$primary_color")
    # Apply enhanced color to OpenRGB with static mode
    openrgb -c "$enhanced_color" --mode static 2>/dev/null || true
  fi
}

apply_sddm() {
  SDDM_THEME_CONFIG="/usr/share/sddm/themes/sugar-candy/theme.conf"
  
  # Check if SDDM theme config exists
  if [ ! -f "$SDDM_THEME_CONFIG" ]; then
    return
  fi
  
  # Find required color values from material_colors.scss
  local main_color="" accent_color="" bg_color="" login_button_color=""
  for i in "${!colorlist[@]}"; do
    case "${colorlist[$i]}" in
      '$onBackground') main_color="${colorvalues[$i]}" ;;
      '$primary') accent_color="${colorvalues[$i]}" ;;
      '$background') bg_color="${colorvalues[$i]}" ;;
      '$onPrimary') login_button_color="${colorvalues[$i]}" ;;
    esac
  done
  
  # Update MainColour (text and UI elements)
  if [ -n "$main_color" ]; then
    sed -i "s/^MainColour=.*/MainColour=\"$main_color\"/" "$SDDM_THEME_CONFIG"
  fi
  
  # Update AccentColour (focused elements)
  if [ -n "$accent_color" ]; then
    sed -i "s/^AccentColour=.*/AccentColour=\"$accent_color\"/" "$SDDM_THEME_CONFIG"
  fi
  
  # Update BackgroundColour (form background)
  if [ -n "$bg_color" ]; then
    sed -i "s/^BackgroundColour=.*/BackgroundColour=\"$bg_color\"/" "$SDDM_THEME_CONFIG"
  fi
  
  # Update OverrideLoginButtonTextColour (login button text)
  if [ -n "$login_button_color" ]; then
    sed -i "s/^OverrideLoginButtonTextColour=.*/OverrideLoginButtonTextColour=\"$login_button_color\"/" "$SDDM_THEME_CONFIG"
  fi
}

apply_hypr() {
  # Update Hyprland colors.conf with term6 value for fullscreen border color
  HYPR_COLORS_FILE="$HOME/.config/hypr/hyprland/colors.conf"
  
  if [ -f "$HYPR_COLORS_FILE" ]; then
    # Find term6 value for hyprland border color
    term6_value=""
    for i in "${!colorlist[@]}"; do
      if [[ "${colorlist[$i]}" == "\$term6" ]]; then
        term6_value="${colorvalues[$i]#\#}"  # Remove # if present
        break
      fi
    done
    
    if [ -n "$term6_value" ]; then
      # Update the fullscreen windowrulev2 border color
      sed -i "s/windowrulev2 = bordercolor rgba([^)]*), fullscreen:1/windowrulev2 = bordercolor rgba(${term6_value}AA), fullscreen:1/g" "$HYPR_COLORS_FILE"
    fi
    
  fi
}

apply_kitty() {
  KITTY_CONFIG_FILE="$XDG_CONFIG_HOME/kitty/kitty.conf"
  
  if [ -f "$KITTY_CONFIG_FILE" ]; then
    # Get color values
    local bg="" fg="" term_colors=()
    for i in "${!colorlist[@]}"; do
      case "${colorlist[$i]}" in
        '$background') bg="${colorvalues[$i]}" ;;
        '$onBackground') fg="${colorvalues[$i]}" ;;
        '$term0') term_colors[0]="${colorvalues[$i]}" ;;
        '$term1') term_colors[1]="${colorvalues[$i]}" ;;
        '$term2') term_colors[2]="${colorvalues[$i]}" ;;
        '$term3') term_colors[3]="${colorvalues[$i]}" ;;
        '$term4') term_colors[4]="${colorvalues[$i]}" ;;
        '$term5') term_colors[5]="${colorvalues[$i]}" ;;
        '$term6') term_colors[6]="${colorvalues[$i]}" ;;
        '$term7') term_colors[7]="${colorvalues[$i]}" ;;
        '$term8') term_colors[8]="${colorvalues[$i]}" ;;
        '$term9') term_colors[9]="${colorvalues[$i]}" ;;
        '$term10') term_colors[10]="${colorvalues[$i]}" ;;
        '$term11') term_colors[11]="${colorvalues[$i]}" ;;
        '$term12') term_colors[12]="${colorvalues[$i]}" ;;
        '$term13') term_colors[13]="${colorvalues[$i]}" ;;
        '$term14') term_colors[14]="${colorvalues[$i]}" ;;
        '$term15') term_colors[15]="${colorvalues[$i]}" ;;
      esac
    done
    
    # Remove everything after # Theme
    sed -i '/^# Theme$/,$d' "$KITTY_CONFIG_FILE"
    
    # Append new theme
    cat >> "$KITTY_CONFIG_FILE" << EOF
# Theme
foreground              $fg
background              $bg
selection_foreground    $bg
selection_background    $fg
cursor                  $fg
cursor_text_color       $bg

color0 ${term_colors[0]}
color8 ${term_colors[8]}
color1 ${term_colors[1]}
color9 ${term_colors[9]}
color2 ${term_colors[2]}
color10 ${term_colors[10]}
color3 ${term_colors[3]}
color11 ${term_colors[11]}
color4 ${term_colors[4]}
color12 ${term_colors[12]}
color5 ${term_colors[5]}
color13 ${term_colors[13]}
color6 ${term_colors[6]}
color14 ${term_colors[14]}
color7 ${term_colors[7]}
color15 ${term_colors[15]}
EOF
    
    # Signal running kitty instances to reload config
    pkill -USR1 kitty 2>/dev/null || true
  fi
}

apply_fish() {
  # Check if fish shell is installed
  if ! command -v fish >/dev/null 2>&1; then
    return
  fi
  
  # Get dark mode setting
  local is_dark_mode=""
  for i in "${!colorlist[@]}"; do
    if [[ "${colorlist[$i]}" == "\$darkmode" ]]; then
      is_dark_mode="${colorvalues[$i]}"
      break
    fi
  done
  
  # Apply fish color scheme - same default theme for both dark and light mode
  fish -c "set -U fish_color_autosuggestion 555 brblack" 2>/dev/null || true
  fish -c "set -U fish_color_cancel -r" 2>/dev/null || true
  fish -c "set -U fish_color_command blue" 2>/dev/null || true
  fish -c "set -U fish_color_comment red" 2>/dev/null || true
  fish -c "set -U fish_color_cwd green" 2>/dev/null || true
  fish -c "set -U fish_color_cwd_root red" 2>/dev/null || true
  fish -c "set -U fish_color_end green" 2>/dev/null || true
  fish -c "set -U fish_color_error brred" 2>/dev/null || true
  fish -c "set -U fish_color_escape brcyan" 2>/dev/null || true
  fish -c "set -U fish_color_history_current --bold" 2>/dev/null || true
  fish -c "set -U fish_color_host normal" 2>/dev/null || true
  fish -c "set -U fish_color_host_remote yellow" 2>/dev/null || true
  fish -c "set -U fish_color_normal normal" 2>/dev/null || true
  fish -c "set -U fish_color_operator brcyan" 2>/dev/null || true
  fish -c "set -U fish_color_param cyan" 2>/dev/null || true
  fish -c "set -U fish_color_quote yellow" 2>/dev/null || true
  fish -c "set -U fish_color_redirection cyan --bold" 2>/dev/null || true
  fish -c "set -U fish_color_search_match --background=111" 2>/dev/null || true
  fish -c "set -U fish_color_selection white --bold --background=brblack" 2>/dev/null || true
  fish -c "set -U fish_color_status red" 2>/dev/null || true
  fish -c "set -U fish_color_user brgreen" 2>/dev/null || true
  fish -c "set -U fish_color_valid_path --underline" 2>/dev/null || true
  fish -c "set -U fish_pager_color_completion normal" 2>/dev/null || true
  fish -c "set -U fish_pager_color_description B3A06D yellow -i" 2>/dev/null || true
  fish -c "set -U fish_pager_color_prefix cyan --bold --underline" 2>/dev/null || true
  fish -c "set -U fish_pager_color_progress brwhite --background=cyan" 2>/dev/null || true
  fish -c "set -U fish_pager_color_selected_background -r" 2>/dev/null || true
}

apply_qt &
apply_term &
apply_hypr &
apply_kitty &
apply_fish &
apply_openrgb &
apply_sddm &
