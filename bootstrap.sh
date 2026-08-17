#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  JarvOS — full-system bootstrap (bare Arch → this box)        ║
# ║  Packages → desktop (install.sh) → services → groups → done   ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./bootstrap.sh                 # core desktop only (the beautiful OS)
#   ./bootstrap.sh --core          # same as no flags (explicit)
#   ./bootstrap.sh --apps          # + browsers/editors/media
#   ./bootstrap.sh --security      # + security/RE toolkit (public tools)
#   ./bootstrap.sh --full          # = --apps --security + optional services
#   ./bootstrap.sh --full-services # enable optional services (docker/virt/...)
#
# Idempotent: safe to re-run. Never installs proprietary pkgs unless --security
# is given, and even then forticlient/powershell are best-effort.
set -euo pipefail
cd "$(dirname "$0")"
base="$(pwd)"

RED='\e[31m'; GREEN='\e[32m'; BLUE='\e[34m'; YELLOW='\e[33m'; NC='\e[0m'
step(){ echo -e "${BLUE}[bootstrap] $1${NC}"; }
ok(){ echo -e "${GREEN}[bootstrap] ✓ $1${NC}"; }
warn(){ echo -e "${YELLOW}[bootstrap] ⚠ $1${NC}"; }

# In arch-chroot there is no user manager: `systemctl --user` cannot connect.
# Fall back to --global (enables for all users; same effect for a fresh box).
enable_user_unit(){
    if systemctl --user enable "$1" 2>/dev/null; then return 0; fi
    sudo systemctl --global enable "$1"
}

APPS=false; SECURITY=false; FULL_SERVICES=false
for a in "$@"; do case "$a" in
    --core) ;;
    --apps) APPS=true;;
    --security) SECURITY=true;;
    --full-services) FULL_SERVICES=true;;
    --full) APPS=true; SECURITY=true; FULL_SERVICES=true;;
    --help|-h) sed -n '2,19p' "$0" | sed 's/^# \?//'; exit 0;;
    *) warn "unknown flag: $a";;
esac; done

command -v pacman >/dev/null || { echo "Arch Linux only."; exit 1; }
[[ $EUID -eq 0 ]] && { echo "Run as your user, not root."; exit 1; }

pkglist(){ grep -vE '^\s*#|^\s*$' "$1"; }

# 1. yay -----------------------------------------------------------------
if ! command -v yay >/dev/null; then
    step "installing yay…"
    sudo pacman -S --needed --noconfirm base-devel git
    tmp=$(mktemp -d); git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm ); rm -rf "$tmp"
fi
ok "yay ready"

# 2. packages ------------------------------------------------------------
step "installing core desktop packages…"
pkglist dependencies.txt | xargs -r yay -S --needed --noconfirm
pkglist system/packages/aur-core.txt | xargs -r yay -S --needed --noconfirm
ok "core packages installed"

if $APPS; then
    step "installing optional apps…"
    pkglist system/packages/aur-apps.txt | xargs -r yay -S --needed --noconfirm || warn "some apps failed"
fi
if $SECURITY; then
    step "installing security toolkit (best-effort; proprietary may prompt)…"
    pkglist system/packages/aur-security.txt | while read -r p; do
        yay -S --needed --noconfirm "$p" || warn "skip $p"
    done
    for r in chsoares/ezpz chsoares/ctf.fish; do
        d="${JARVOS_HOME:-$HOME}/${r#*/}"
        [[ -d "$d/.git" ]] || git clone --depth 1 "https://github.com/$r.git" "$d" || warn "clone $r failed"
    done
    ok "ezpz + ctf.fish (chsoares) in ${JARVOS_HOME:-$HOME}"
fi

# 3. desktop layer (configs, venv, themes, base groups/services) ---------
step "running desktop installer (install.sh)…"
bash install.sh "$@" || warn "install.sh reported issues; continuing"

# 3b. hypr-box — the AI control layer (JarvOS is "AI-native")
step "installing hypr-box (uv tool)…"
# hypr-box is a submodule: a plain `git clone` of JarvOS leaves it empty.
git -C "$base" submodule update --init --recursive hypr-box 2>/dev/null || true
uv tool install --force "$base/hypr-box" && ok "hypr-box installed" || warn "hypr-box install failed"

# 4. per-host monitors.conf from template --------------------------------
mon="$HOME/.config/hypr/hyprland/monitors.conf"
if [[ ! -f "$mon" && -f "$HOME/.config/hypr/hyprland/monitors-example.conf" ]]; then
    cp "$HOME/.config/hypr/hyprland/monitors-example.conf" "$mon"
    warn "created monitors.conf from example — edit it for your displays (hyprctl monitors)"
fi

# 5. services ------------------------------------------------------------
step "enabling services…"
while read -r scope unit tier; do
    [[ -z "${scope:-}" || "$scope" == \#* ]] && continue
    [[ "$tier" == "optional" ]] && ! $FULL_SERVICES && continue
    if [[ "$scope" == system ]]; then
        sudo systemctl enable "$unit" 2>/dev/null && ok "system: $unit" || warn "skip $unit"
    else
        enable_user_unit "$unit" 2>/dev/null && ok "user: $unit" || warn "skip $unit"
    fi
done < system/services/enable.txt

# 6. groups --------------------------------------------------------------
step "ensuring user groups…"
for g in video input i2c docker libvirt; do
    getent group "$g" >/dev/null || continue
    id -nG "$USER" | grep -qw "$g" || { sudo usermod -aG "$g" "$USER" && ok "added to $g"; }
done

echo
ok "JarvOS bootstrap complete."
echo -e "${YELLOW}Next: log out and pick the Hyprland session in SDDM, or run:${NC}"
echo "  qs -p ~/.config/quickshell/jarvos/shell.qml"
echo -e "${YELLOW}Edit ~/.config/hypr/hyprland/monitors.conf for your display layout.${NC}"
