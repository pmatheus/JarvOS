#!/usr/bin/env bash

# ╔══════════════════════════════════════════════════════════════╗
# ║  JarvOS — Arch Linux Desktop Environment Installer          ║
# ║  Hyprland + QuickShell + Material Design 3                  ║
# ║  github.com/pmatheus/JarvOS                                 ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# One-liner support: if run via curl, clone and re-exec
if [[ ! -f "dependencies.txt" ]]; then
    echo -e "\e[34m[JarvOS] Cloning repository...\e[0m"
    git clone --depth 1 https://github.com/pmatheus/JarvOS.git ~/JarvOS
    cd ~/JarvOS
    exec bash install.sh "$@"
fi

cd "$(dirname "$0")"
export base="$(pwd)"

# Colors
RED='\e[31m'; GREEN='\e[32m'; BLUE='\e[34m'; YELLOW='\e[33m'
CYAN='\e[36m'; BOLD='\e[1m'; DIM='\e[2m'; NC='\e[0m'

# Parse flags
MINIMAL=false
for arg in "$@"; do
    case $arg in
        --minimal) MINIMAL=true ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --minimal    Skip GRUB theme, SDDM setup, and firewall"
            echo "  --help       Show this message"
            exit 0
            ;;
    esac
done

#####################################################################################
# Functions
#####################################################################################

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo '       ╦╔═╗╦═╗╦  ╦╔═╗╔═╗'
    echo '       ║╠═╣╠╦╝╚╗╔╝║ ║╚═╗'
    echo '      ╚╝╩ ╩╩╚═ ╚╝ ╚═╝╚═╝'
    echo -e "${DIM}    Hyprland + QuickShell Desktop${NC}"
    echo ""
}

step()    { echo -e "${BLUE}[JarvOS] $1${NC}"; }
ok()      { echo -e "${GREEN}[JarvOS] ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}[JarvOS] ⚠ $1${NC}"; }
err()     { echo -e "${RED}[JarvOS] ✗ $1${NC}"; }

check_arch() {
    if ! command -v pacman >/dev/null 2>&1; then
        err "pacman not found. This script only works on Arch Linux."
        exit 1
    fi
}

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Do not run as root. The script will use sudo when needed."
        exit 1
    fi
}

install_yay() {
    if command -v yay >/dev/null 2>&1; then
        ok "yay already installed"
        return 0
    fi
    step "Installing yay AUR helper..."
    sudo pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin && makepkg -si --noconfirm
    cd "$base" && rm -rf /tmp/yay-bin
    ok "yay installed"
}

install_packages() {
    step "Installing packages from dependencies.txt..."
    grep -v '^#' dependencies.txt | grep -v '^$' | xargs yay -S --needed --noconfirm
    ok "All packages installed"
}

setup_python_environment() {
    step "Setting up Python environment for QuickShell..."
    export UV_NO_MODIFY_PATH=1
    export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"

    if [[ ! -d "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]]; then
        mkdir -p "$(dirname "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
        step "Creating Python virtual environment..."
        uv venv --prompt .venv "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" -p 3.12
    fi

    source "$ILLOGICAL_IMPULSE_VIRTUAL_ENV/bin/activate"
    uv pip install -r requirements.txt
    deactivate
    ok "Python environment ready"
}

setup_user_groups() {
    step "Configuring user groups..."
    user_groups=$(groups "$(whoami)")
    groups_to_add=()
    for group in video i2c input; do
        [[ ! $user_groups =~ $group ]] && groups_to_add+=("$group")
    done
    if [[ ${#groups_to_add[@]} -gt 0 ]]; then
        sudo usermod -aG "$(IFS=,; echo "${groups_to_add[*]}")" "$(whoami)"
        ok "Added user to groups: ${groups_to_add[*]}"
    else
        ok "User already in required groups"
    fi

    if [[ ! -f "/etc/modules-load.d/i2c-dev.conf" ]] || ! grep -q "i2c-dev" "/etc/modules-load.d/i2c-dev.conf"; then
        echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
    fi
}

setup_services() {
    step "Enabling services..."
    systemctl --user enable ydotool --now 2>/dev/null || true
    sudo systemctl enable bluetooth --now 2>/dev/null || true

    # OpenRGB
    sudo tee /lib/systemd/system/openrgb.service > /dev/null << 'EOF'
[Unit]
Description=Run OpenRGB server
After=network.target lm_sensors.service
[Service]
ExecStart=/usr/bin/openrgb --server --server-host 127.0.0.1 --config /etc/openrgb
Restart=on-failure
RuntimeDirectory=openrgb
WorkingDirectory=/run/openrgb
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable openrgb --now 2>/dev/null || true
    ok "Services configured"
}

setup_desktop_settings() {
    step "Configuring desktop environment..."
    gsettings set org.gnome.desktop.interface font-name 'Rubik 11' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

    sudo mkdir -p /usr/share/icons/default
    sudo tee /usr/share/icons/default/index.theme > /dev/null << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Classic
EOF
    ok "Desktop settings applied"
}

setup_grub_timeshift() {
    step "Setting up GRUB with Timeshift integration..."
    if [[ ! -d /sys/firmware/efi ]]; then
        warn "BIOS system detected — skipping GRUB install (manual setup needed)"
        return 0
    fi
    sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

    sudo mkdir -p /etc/systemd/system/grub-btrfsd.service.d/
    sudo tee /etc/systemd/system/grub-btrfsd.service.d/override.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable grub-btrfsd --now 2>/dev/null || true
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "GRUB configured"
}

setup_grub_theme() {
    if [[ -f "$base/grub/install-theme.sh" ]]; then
        step "Installing GRUB theme..."
        sudo rm -rf /boot/grub/themes/Particle* 2>/dev/null || true
        cd "$base/grub" && sudo ./install-theme.sh && cd "$base"
        ok "GRUB theme installed"
    fi
}

setup_sddm() {
    step "Setting up SDDM..."
    if [[ -d "$base/sddm" ]]; then
        sudo mkdir -p /usr/share/sddm/themes/
        sudo cp -rf "$base/sddm" /usr/share/sddm/themes/sugar-candy
        sudo chmod -R 777 /usr/share/sddm/themes/sugar-candy
    fi

    sudo tee /etc/sddm.conf > /dev/null << 'EOF'
[Theme]
Current=sugar-candy
CursorSize=24
CursorTheme=Bibata-Modern-Classic
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
[Users]
MaximumUid=60513
MinimumUid=1000
EOF
    sudo systemctl disable display-manager.service 2>/dev/null || true
    sudo systemctl enable sddm.service 2>/dev/null || true
    ok "SDDM configured"
}

setup_fish_plugins() {
    step "Installing Fish plugins..."
    command -v fish >/dev/null 2>&1 || { warn "Fish not found"; return 0; }

    fish -c "
        if not functions -q fisher
            curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
            fisher install jorgebucaran/fisher
        end
        fisher install PatrickF1/fzf.fish 2>/dev/null
        fisher install icezyclon/zoxide.fish 2>/dev/null
    " 2>/dev/null || warn "Fish plugins may need manual installation"
    ok "Fish plugins ready"
}

install_dotfiles() {
    step "Installing dotfiles..."
    XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    mkdir -p "$XDG_CONFIG_HOME"

    cp -rf config/.config/* "$XDG_CONFIG_HOME/"

    # Create default monitors.conf if missing
    MONITORS_CONF="$XDG_CONFIG_HOME/hypr/hyprland/monitors.conf"
    if [[ ! -f "$MONITORS_CONF" ]]; then
        cat > "$MONITORS_CONF" << 'EOF'
# MONITOR CONFIG — edit for your setup
# Run `hyprctl monitors` to see device names
monitor = , preferred, auto, 1
EOF
        ok "Created default monitors.conf"
    fi

    # Wallpaper symlink
    mkdir -p "$HOME/Pictures"
    WALLPAPER_LINK="$HOME/Pictures/Wallpapers"
    if [[ ! -L "$WALLPAPER_LINK" && ! -d "$WALLPAPER_LINK" ]]; then
        ln -s "$base/wallpapers" "$WALLPAPER_LINK"
    fi

    # Reload if running
    pgrep -x hyprland >/dev/null && hyprctl reload 2>/dev/null || true
    ok "Dotfiles installed"
}

#####################################################################################
# Main
#####################################################################################

print_banner

check_arch
check_not_root

step "Updating system..."
sudo pacman -Syu --noconfirm

install_yay
install_packages
setup_python_environment
setup_user_groups
setup_services
setup_desktop_settings
install_dotfiles
setup_fish_plugins

if [[ "$MINIMAL" == false ]]; then
    setup_sddm
    setup_grub_timeshift
    setup_grub_theme
fi

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  JarvOS installation complete!                              ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Reboot your system"
echo "  2. Select 'Hyprland' at the login screen"
echo "  3. Press Super+H to see the keybinding cheatsheet"
echo ""
echo -e "${CYAN}Key bindings:${NC}"
echo "  Super          Overview/launcher"
echo "  Super+Return   Terminal"
echo "  Super+E        File manager"
echo "  Super+W        Browser"
echo "  Super+N        Sidebar"
echo "  Super+H        Cheatsheet"
echo "  Super+Space    Spotlight search"
echo ""
if [[ "$MINIMAL" == false ]]; then
    warn "Do NOT select UWSM session — use regular Hyprland"
fi
