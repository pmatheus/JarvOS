#!/usr/bin/env bash
# plymouth/install-theme.sh — install the JarvOS Plymouth theme (boot splash and
# disk password prompt) and enable it.
#
# Adds the `plymouth` hook only to a systemd-based mkinitcpio config (right
# after `systemd`); a busybox `udev`/`encrypt` config is left alone, so a
# password-only rescue image keeps booting without Plymouth. Adds `splash` to
# GRUB_CMDLINE_LINUX_DEFAULT, then rebuilds the initramfs and grub.cfg.
# Idempotent; run as root.
#
# Seams for tests: JARVOS_PLYMOUTH_THEMES, JARVOS_MKINITCPIO_CONF,
# JARVOS_GRUB_DEFAULTS, JARVOS_GRUB_CFG, JARVOS_PLYMOUTH_SET_THEME,
# JARVOS_MKINITCPIO, JARVOS_GRUB_MKCONFIG.
set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/jarvos/theme"
THEMES="${JARVOS_PLYMOUTH_THEMES:-/usr/share/plymouth/themes}"
MKCONF="${JARVOS_MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"
DEFAULTS="${JARVOS_GRUB_DEFAULTS:-/etc/default/grub}"
SET_THEME="${JARVOS_PLYMOUTH_SET_THEME:-plymouth-set-default-theme}"
MKINITCPIO="${JARVOS_MKINITCPIO:-mkinitcpio}"
MKCONFIG="${JARVOS_GRUB_MKCONFIG:-grub-mkconfig}"
GRUB_CFG="${JARVOS_GRUB_CFG:-/boot/grub/grub.cfg}"
DEST="$THEMES/jarvos"

die() { printf 'plymouth install-theme: %s\n' "$*" >&2; exit 1; }
[[ -f "$SRC/jarvos.plymouth" ]] || die "theme not found at $SRC"
if [[ -z "${JARVOS_PLYMOUTH_THEMES:-}" && $EUID -ne 0 ]]; then die "run as root"; fi
command -v "$SET_THEME" >/dev/null || die "plymouth is not installed"

mkdir -p "$THEMES"
rm -rf "$DEST.new"
cp -r "$SRC" "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"
"$SET_THEME" jarvos

hooks="$(grep -E '^HOOKS=' "$MKCONF" || true)"
if [[ "$hooks" =~ [\(\ ]systemd[\ \)] && ! "$hooks" =~ [\(\ ]plymouth[\ \)] ]]; then
    [[ -e "$MKCONF.bak-jarvos-plymouth" ]] || cp -a "$MKCONF" "$MKCONF.bak-jarvos-plymouth"
    sed -i -E '/^HOOKS=/ s/([( ])systemd([ )])/\1systemd plymouth\2/' "$MKCONF"
elif [[ ! "$hooks" =~ [\(\ ]systemd[\ \)] ]]; then
    printf 'plymouth install-theme: %s has no systemd hook; leaving HOOKS alone\n' "$MKCONF" >&2
fi

if [[ -f "$DEFAULTS" ]] && ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bsplash\b' "$DEFAULTS"; then
    [[ -e "$DEFAULTS.bak-jarvos-plymouth" ]] || cp -a "$DEFAULTS" "$DEFAULTS.bak-jarvos-plymouth"
    sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"/\1 splash"/' "$DEFAULTS"
fi

"$MKINITCPIO" -P
if [[ -f "$DEFAULTS" ]]; then "$MKCONFIG" -o "$GRUB_CFG"; fi
printf 'JarvOS Plymouth theme installed in %s\n' "$DEST"
