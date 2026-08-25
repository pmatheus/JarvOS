#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  JarvOS — full-system bootstrap (bare Arch → this box)        ║
# ║  Packages → desktop (install.sh) → services → groups → done   ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./bootstrap.sh --stage1        # the installer's path: pacman only, no builds
#   ./bootstrap.sh                 # core desktop only (the beautiful OS)
#   ./bootstrap.sh --core          # same as no flags (explicit)
#   ./bootstrap.sh --apps          # + browsers/editors/media
#   ./bootstrap.sh --security      # + security/RE toolkit (public tools)
#   ./bootstrap.sh --full          # = --apps --security + optional services
#   ./bootstrap.sh --full-services # enable optional services (docker/virt/...)
#   ./bootstrap.sh --dry-run       # print every side effect instead of running it
#
# --stage1 is what the ISO runs inside the freshly installed system. It installs
# system/packages/stage1.txt with pacman and nothing else: no AUR helper, no
# makepkg, no pip resolve, no plugin fetched off GitHub. Every AUR package in
# that list is served prebuilt by the [jarvos] binary repository, and a name the
# repositories cannot resolve stops the install with its name in the message
# rather than quietly falling back to building it. Everything stage 1 leaves out
# is offered by the Setup app at first login.
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
err(){ echo -e "${RED}[bootstrap] ✗ $1${NC}" >&2; }

DRY_RUN=false

# Single choke point for side effects, so --dry-run can print the whole sequence
# without touching a machine -- which is the only way the installer's contract
# with this script is testable at all.
run(){
    if $DRY_RUN; then
        printf '+'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}

# Root-owned config files, traced the same way. Content is passed without its
# trailing newline; both branches add it.
sudo_write(){ # sudo_write <mode> <path> <content>
    local mode=$1 path=$2 content=$3
    if $DRY_RUN; then
        printf '+ sudo install -m %s /dev/stdin %s <<EOF\n%s\n+ EOF\n' "$mode" "$path" "$content"
    else
        sudo mkdir -p "$(dirname "$path")"
        printf '%s\n' "$content" | sudo tee "$path" >/dev/null
        sudo chmod "$mode" "$path"
    fi
}

user_write(){ # user_write <path> <content>
    local path=$1 content=$2
    if $DRY_RUN; then
        printf '+ install /dev/stdin %s <<EOF\n%s\n+ EOF\n' "$path" "$content"
    else
        mkdir -p "$(dirname "$path")"
        printf '%s\n' "$content" > "$path"
    fi
}

# In arch-chroot there is no user manager: `systemctl --user` cannot connect.
# Fall back to --global (enables for all users; same effect for a fresh box).
enable_user_unit(){
    if systemctl --user enable "$1" 2>/dev/null; then return 0; fi
    sudo -n systemctl --global enable "$1"
}

STAGE1=false; APPS=false; SECURITY=false; FULL_SERVICES=false
for a in "$@"; do case "$a" in
    --core) ;;
    --stage1) STAGE1=true;;
    --apps) APPS=true;;
    --security) SECURITY=true;;
    --full-services) FULL_SERVICES=true;;
    --full) APPS=true; SECURITY=true; FULL_SERVICES=true;;
    --dry-run) DRY_RUN=true;;
    --help|-h) sed -n '2,26p' "$0" | sed 's/^# \?//'; exit 0;;
    # Fatal, not a warning: a typo used to mean "quietly install everything the
    # old way", which is exactly the forty-minute install this stage replaces.
    *) err "unknown flag: $a"; exit 2;;
esac; done

command -v pacman >/dev/null || { err "Arch Linux only."; exit 1; }
[[ $EUID -eq 0 ]] && { err "Run as your user, not root."; exit 1; }

# Only the stage 1 path routes every side effect through run(); the full bootstrap
# hands whole package lists to yay and would execute them regardless. A --dry-run
# that half-runs is worse than one that refuses.
if $DRY_RUN && ! $STAGE1; then
    err "--dry-run is only implemented for --stage1"
    exit 2
fi

pkglist(){ grep -vE '^\s*#|^\s*$' "$1"; }

#####################################################################################
# Stage 1 — the installer's path
#####################################################################################

# Nothing here may build anything. If a name does not resolve, the [jarvos]
# repository is missing, unsynced, or short a package, and the honest thing is to
# stop and say which -- a fallback to makepkg is the failure mode this replaces.
resolve_or_die(){
    local p missing=()
    for p in "$@"; do
        pacman -Si -- "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    ((${#missing[@]} == 0)) && return 0
    err "stage 1 cannot resolve ${#missing[@]} package(s):"
    printf '    %s\n' "${missing[@]}" >&2
    err "these must be served prebuilt by the [jarvos] binary repository -- stage 1 never builds."
    err "check that /etc/pacman.conf carries the [jarvos] section, then: sudo pacman -Sy"
    exit 1
}

stage1_packages(){
    local list="${JARVOS_STAGE1_LIST:-$base/system/packages/stage1.txt}"
    [[ -r "$list" ]] || { err "missing package list: $list"; exit 1; }
    mapfile -t pkgs < <(pkglist "$list")
    ((${#pkgs[@]})) || { err "no packages in $list"; exit 1; }

    step "refreshing the package databases…"
    run sudo pacman -Sy --noconfirm

    step "resolving ${#pkgs[@]} stage 1 packages…"
    resolve_or_die "${pkgs[@]}"

    step "installing ${#pkgs[@]} stage 1 packages with pacman…"
    run sudo pacman -S --needed --noconfirm --disable-download-timeout "${pkgs[@]}"
    ok "stage 1 packages installed"
}

deploy_dotfiles(){
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" mon wall
    step "deploying dotfiles into $cfg…"
    run mkdir -p "$cfg"
    run cp -rf "$base/config/.config/." "$cfg/"

    # Every migration this release ships is already true of a fresh install.
    # Without this, migration N would have to be safe on a machine that never
    # had state N-1 — a contract that collapses after about fifty of them.
    step "marking shipped migrations as applied…"
    run "$base/bin/jarvos-migrate" --mark-all

    mon="$cfg/hypr/hyprland/monitors.conf"
    if $DRY_RUN || [[ ! -f "$mon" ]]; then
        user_write "$mon" "# MONITOR CONFIG — edit for your setup
# Run \`hyprctl monitors\` to see device names
monitor = , preferred, auto, 1"
    fi

    wall="$HOME/Pictures/Wallpapers"
    run mkdir -p "$HOME/Pictures"
    if $DRY_RUN || [[ ! -e "$wall" ]]; then
        run ln -sfn "$base/wallpapers" "$wall"
    fi
    ok "dotfiles deployed"
}

# switchwall.sh sources this venv and imports materialyoucolor, PIL and numpy.
# --system-site-packages is what makes that work against the pacman-installed
# modules: stage 1 must not resolve requirements.txt, because pygobject, pycairo
# and libsass would be compiled right here on the user's machine.
setup_venv(){
    local venv="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
    step "creating the quickshell virtualenv…"
    run mkdir -p "$(dirname "$venv")"
    run uv venv --system-site-packages --prompt .venv "$venv"
    ok "virtualenv ready (system site packages; nothing built)"
}

setup_groups(){
    local g groups=()
    for g in video input i2c; do
        getent group "$g" >/dev/null 2>&1 && groups+=("$g")
    done
    if ((${#groups[@]})); then
        step "adding $USER to ${groups[*]}…"
        run sudo usermod -aG "$(IFS=,; echo "${groups[*]}")" "$USER"
    fi
    sudo_write 644 /etc/modules-load.d/i2c-dev.conf "i2c-dev"
}

setup_appearance(){
    step "pointing the default cursor theme at Bibata…"
    sudo_write 644 /usr/share/icons/default/index.theme "[Icon Theme]
Inherits=Bibata-Modern-Classic"
    # switchwall.sh asks gsettings which mode to generate colours for. In a chroot
    # there is no session bus to answer, and the desktop sets it again on first
    # login, so this is best-effort by design.
    if ! $DRY_RUN; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'Rubik 11' 2>/dev/null || true
    fi
}

setup_sddm(){
    step "installing the SDDM sugar-candy theme…"
    if [[ -d "$base/sddm" ]]; then
        run sudo mkdir -p /usr/share/sddm/themes
        run sudo rm -rf /usr/share/sddm/themes/sugar-candy
        run sudo cp -rf "$base/sddm" /usr/share/sddm/themes/sugar-candy
        # 0755, not install.sh's historic 0777: the greeter runs as its own user
        # and never needs to write to its own theme.
        run sudo chmod -R 755 /usr/share/sddm/themes/sugar-candy
    else
        warn "no sddm/ directory in the repo; keeping the stock theme"
    fi
    sudo_write 644 /etc/sddm.conf "[Theme]
Current=sugar-candy
CursorSize=24
CursorTheme=Bibata-Modern-Classic
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
[Users]
MaximumUid=60513
MinimumUid=1000"
}

# The boot menu is the first thing the machine draws, so the theme belongs in
# stage 1 -- but archinstall owns the bootloader, so this only dresses it. A
# machine that boots some other way simply keeps its menu.
setup_grub_theme(){
    if [[ ! -d /boot/grub ]]; then
        warn "no /boot/grub; skipping the GRUB theme"
        return 0
    fi
    if [[ ! -x "$base/grub/install-theme.sh" ]]; then
        warn "grub/install-theme.sh missing; skipping the GRUB theme"
        return 0
    fi
    step "installing the GRUB theme…"
    run sudo "$base/grub/install-theme.sh" || warn "GRUB theme failed; continuing"
}

enable_services(){
    local scope unit tier
    step "enabling services…"
    while read -r scope unit tier; do
        [[ -z "${scope:-}" || "$scope" == \#* ]] && continue
        [[ "${tier:-core}" == "optional" ]] && ! $FULL_SERVICES && continue
        if [[ "$scope" == system ]]; then
            run sudo systemctl enable "$unit" && ok "system: $unit" || warn "skip $unit"
        else
            run enable_user_unit "$unit" && ok "user: $unit" || warn "skip $unit"
        fi
    done < "$base/system/services/enable.txt"
}

if $STAGE1; then
    stage1_packages
    deploy_dotfiles
    setup_venv
    setup_groups
    setup_appearance
    setup_sddm
    setup_grub_theme
    enable_services
    echo
    ok "JarvOS stage 1 complete — the desktop is installed."
    echo -e "${YELLOW}The Setup app offers the remaining modules at first login.${NC}"
    exit 0
fi

#####################################################################################
# Full bootstrap — for an existing box, where building from the AUR is acceptable
#####################################################################################

# 1. yay -----------------------------------------------------------------
if ! command -v yay >/dev/null; then
    step "installing yay…"
    run sudo pacman -S --needed --noconfirm base-devel git
    tmp=$(mktemp -d); run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    ( cd "$tmp/yay" && run makepkg -si --noconfirm ); rm -rf "$tmp"
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
    clone_failed=false
    for r in chsoares/ezpz chsoares/ctf.fish; do
        d="${JARVOS_HOME:-$HOME}/${r#*/}"
        [[ -d "$d/.git" ]] || git clone --depth 1 "https://github.com/$r.git" "$d" \
            || { warn "clone $r failed"; clone_failed=true; }
    done
    if $clone_failed; then
        warn "ezpz/ctf.fish incomplete in ${JARVOS_HOME:-$HOME} — see clone errors above"
    else
        ok "ezpz + ctf.fish (chsoares) in ${JARVOS_HOME:-$HOME}"
    fi
fi

# 3. desktop layer (configs, venv, themes, base groups/services) ---------
step "running desktop installer (install.sh)…"
bash install.sh "$@" || warn "install.sh reported issues; continuing"

# 3b. hypr-box — the AI control layer (JarvOS is "AI-native")
step "installing hypr-box (uv tool)…"
# hypr-box is a submodule: a plain `git clone` of JarvOS leaves it empty.
git -C "$base" submodule update --init --recursive hypr-box || true
uv tool install --force "$base/hypr-box" && ok "hypr-box installed" || warn "hypr-box install failed"

# 4. per-host monitors.conf from template --------------------------------
mon="$HOME/.config/hypr/hyprland/monitors.conf"
if [[ ! -f "$mon" && -f "$HOME/.config/hypr/hyprland/monitors-example.conf" ]]; then
    cp "$HOME/.config/hypr/hyprland/monitors-example.conf" "$mon"
    warn "created monitors.conf from example — edit it for your displays (hyprctl monitors)"
fi

# 5. services ------------------------------------------------------------
enable_services

# 6. groups --------------------------------------------------------------
step "ensuring user groups…"
for g in video input i2c docker libvirt; do
    getent group "$g" >/dev/null || continue
    id -nG "$USER" | grep -qw "$g" || { sudo usermod -aG "$g" "$USER" && ok "added to $g"; }
done

echo
ok "JarvOS bootstrap complete."
echo -e "${YELLOW}Next: log out and pick the Hyprland session in SDDM, or run:${NC}"
echo "  systemctl --user start quickshell-jarvos.service   # or: qs -c caelestia"
echo -e "${YELLOW}Edit ~/.config/hypr/hyprland/monitors.conf for your display layout.${NC}"
