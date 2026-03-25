#!/usr/bin/env bash

# Exit immediately if a command fails
set -o errexit

# GRUB theme installation script for Particle-circle-window theme with 2k resolution
readonly THEME_NAME="Particle-circle"
readonly THEME_VARIANT="window"
readonly SCREEN_VARIANT="2k"
# Detect GRUB directory
if [[ -d "/boot/grub" ]]; then
  readonly GRUB_DIR="/boot/grub/themes"
elif [[ -d "/boot/grub2" ]]; then
  readonly GRUB_DIR="/boot/grub2/themes"
else
  readonly GRUB_DIR="/usr/share/grub/themes"
fi
readonly SCRIPT_DIR="$(dirname "$(readlink -m "${0}")")"

# Colors for output
readonly CDEF="\033[0m"
readonly CGSC="\033[0;32m"
readonly CRER="\033[0;31m" 
readonly CWAR="\033[0;33m"
readonly CCIN="\033[0;36m"

# Logging function
log() {
  case ${1} in
    "-s"|"--success") echo -e "\033[1;32m${@/-s/}\033[0m" ;;
    "-e"|"--error") echo -e "\033[1;31m${@/-e/}\033[0m" ;;
    "-w"|"--warning") echo -e "\033[1;33m${@/-w/}\033[0m" ;;
    "-i"|"--info") echo -e "\033[1;36m${@/-i/}\033[0m" ;;
    *) echo -e "$@" ;;
  esac
}

# Check if command exists
has_command() {
  command -v "$1" &> /dev/null
}

# Copy theme files
copy_theme_files() {
  local theme_dir="${GRUB_DIR}/${THEME_NAME}-${THEME_VARIANT}"
  
  log -w "Creating theme directory: ${theme_dir}"
  [[ -d "${theme_dir}" ]] && rm -rf "${theme_dir}"
  mkdir -p "${theme_dir}"
  
  log -i "Installing theme files..."
  
  # Copy font files
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/common/"*.pf2 "${theme_dir}/"
  
  # Copy background
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/backgrounds/backgrounds/background-${THEME_VARIANT}.jpg" "${theme_dir}/background.jpg"
  
  # Copy icons
  mkdir -p "${theme_dir}/icons"
  cp -r --no-preserve=ownership "${SCRIPT_DIR}/assets/assets-icons/icons-${SCREEN_VARIANT}/"* "${theme_dir}/icons/"
  
  # Copy theme configuration
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/config/theme-${THEME_VARIANT}-${SCREEN_VARIANT}.txt" "${theme_dir}/theme.txt"
  
  # Copy selection graphics
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/assets/assets-other/other-${SCREEN_VARIANT}/select_e.png" "${theme_dir}/"
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/assets/assets-other/other-${SCREEN_VARIANT}/select_c.png" "${theme_dir}/"
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/assets/assets-other/other-${SCREEN_VARIANT}/select_w.png" "${theme_dir}/"
  
  # Copy info image
  cp -a --no-preserve=ownership "${SCRIPT_DIR}/assets/assets-other/other-${SCREEN_VARIANT}/${THEME_VARIANT}.png" "${theme_dir}/info.png"
  
  # Use custom background if available
  if [[ -f "${SCRIPT_DIR}/background.jpg" ]]; then
    log -w "Using custom background.jpg..."
    cp -a --no-preserve=ownership "${SCRIPT_DIR}/background.jpg" "${theme_dir}/background.jpg"
    # Convert and auto-orient if imagemagick is available
    if has_command convert; then
      convert -auto-orient "${theme_dir}/background.jpg" "${theme_dir}/background.jpg"
    fi
  fi
  
  log -s "Theme files copied successfully"
}

# Update GRUB configuration
update_grub_config() {
  local theme_dir="${GRUB_DIR}/${THEME_NAME}-${THEME_VARIANT}"
  local grub_config="/etc/default/grub"
  
  log -i "Updating GRUB configuration..."
  
  # Backup original config
  if [[ ! -f "${grub_config}.bak" ]]; then
    cp "${grub_config}" "${grub_config}.bak"
    log -i "Backed up original GRUB config"
  fi
  
  # Set GRUB_THEME
  if grep -q "GRUB_THEME=" "${grub_config}" 2>/dev/null; then
    sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"${theme_dir}/theme.txt\"|" "${grub_config}"
  else
    echo "GRUB_THEME=\"${theme_dir}/theme.txt\"" >> "${grub_config}"
  fi
  
  # Set GRUB_BACKGROUND
  if grep -q "GRUB_BACKGROUND=" "${grub_config}" 2>/dev/null; then
    sed -i "s|.*GRUB_BACKGROUND=.*|GRUB_BACKGROUND=\"${theme_dir}/background.jpg\"|" "${grub_config}"
  else
    echo "GRUB_BACKGROUND=\"${theme_dir}/background.jpg\"" >> "${grub_config}"
  fi
  
  # Set resolution for 2k
  local gfxmode="GRUB_GFXMODE=2560x1440,auto"
  if grep -q "GRUB_GFXMODE=" "${grub_config}" 2>/dev/null; then
    sed -i "s|.*GRUB_GFXMODE=.*|${gfxmode}|" "${grub_config}"
  else
    echo "${gfxmode}" >> "${grub_config}"
  fi
  
  # Disable console terminal to enable graphics
  if grep -q "GRUB_TERMINAL=console" "${grub_config}" 2>/dev/null; then
    sed -i "s|.*GRUB_TERMINAL=.*|#GRUB_TERMINAL=console|" "${grub_config}"
  fi
  
  if grep -q "GRUB_TERMINAL_OUTPUT=console" "${grub_config}" 2>/dev/null; then
    sed -i "s|.*GRUB_TERMINAL_OUTPUT=.*|#GRUB_TERMINAL_OUTPUT=console|" "${grub_config}"
  fi
  
  log -s "GRUB configuration updated"
}

# Update GRUB
update_grub() {
  log -i "Regenerating GRUB configuration..."
  
  if has_command update-grub; then
    update-grub
  elif has_command grub-mkconfig; then
    grub-mkconfig -o /boot/grub/grub.cfg
  elif has_command grub2-mkconfig; then
    # Check for BIOS vs UEFI setup
    if [[ -f /boot/grub2/grub.cfg ]]; then
      grub2-mkconfig -o /boot/grub2/grub.cfg
    elif [[ -f /boot/efi/EFI/*/grub.cfg ]]; then
      # Find the EFI grub config (fedora, arch, etc.)
      local efi_config
      efi_config=$(find /boot/efi/EFI/ -name "grub.cfg" -type f | head -1)
      [[ -n "$efi_config" ]] && grub2-mkconfig -o "$efi_config"
    fi
  else
    log -e "Could not find GRUB update command"
    return 1
  fi
  
  log -s "GRUB configuration regenerated successfully"
}

# Main installation function
install_theme() {
  if [[ $EUID -ne 0 ]]; then
    log -e "This script must be run as root"
    log -i "Usage: sudo $0"
    exit 1
  fi
  
  log -i "Installing ${THEME_NAME}-${THEME_VARIANT} theme with ${SCREEN_VARIANT} resolution..."
  
  copy_theme_files
  update_grub_config
  update_grub
  
  log -s "Theme installation completed successfully!"
  log -w "The new theme will be visible on next reboot."
}

# Run installation
install_theme