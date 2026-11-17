#!/usr/bin/env bash
# grub/install-theme.sh — install the JarvOS GRUB theme and point GRUB at it.
#
# Copies grub/jarvos/theme (assets built by grub/jarvos/build.sh, committed)
# to <grub>/themes/jarvos, sets GRUB_THEME, GRUB_GFXMODE and GRUB_DISTRIBUTOR
# in /etc/default/grub, comments out GRUB_BACKGROUND (the theme draws its own)
# and regenerates grub.cfg. Idempotent; run as root.
#
# Seams for tests: JARVOS_GRUB_ROOT, JARVOS_GRUB_DEFAULTS, JARVOS_GRUB_MKCONFIG.
set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/jarvos/theme"
if [[ -n "${JARVOS_GRUB_ROOT:-}" ]]; then
    GRUB_ROOT="$JARVOS_GRUB_ROOT"
elif [[ -d /boot/grub ]]; then
    GRUB_ROOT=/boot/grub
else
    GRUB_ROOT=/boot/grub2
fi
DEFAULTS="${JARVOS_GRUB_DEFAULTS:-/etc/default/grub}"
MKCONFIG="${JARVOS_GRUB_MKCONFIG:-grub-mkconfig}"
DEST="$GRUB_ROOT/themes/jarvos"

die() { printf 'install-theme: %s\n' "$*" >&2; exit 1; }
[[ -f "$SRC/theme.txt" ]] || die "theme not found at $SRC"
[[ -f "$DEFAULTS" ]] || die "no $DEFAULTS"
if [[ -z "${JARVOS_GRUB_ROOT:-}" && $EUID -ne 0 ]]; then die "run as root"; fi

# Swap the theme directory in whole, so GRUB never sees half a theme.
mkdir -p "$GRUB_ROOT/themes"
rm -rf "$DEST.new"
cp -r "$SRC" "$DEST.new"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"

[[ -e "$DEFAULTS.bak-jarvos-theme" ]] || cp -a "$DEFAULTS" "$DEFAULTS.bak-jarvos-theme"
set_key() {   # set_key KEY VALUE — replace an active or commented line, else append
    if grep -qE "^#?[[:space:]]*$1=" "$DEFAULTS"; then
        sed -i -E "s|^#?[[:space:]]*$1=.*|$1=\"$2\"|" "$DEFAULTS"
    else
        printf '%s="%s"\n' "$1" "$2" >> "$DEFAULTS"
    fi
}
set_key GRUB_THEME "$DEST/theme.txt"
# Laid out for 1080p (percentages, so other sizes work); auto if unsupported.
set_key GRUB_GFXMODE "1920x1080,auto"
set_key GRUB_DISTRIBUTOR "JarvOS"
sed -i -E 's|^GRUB_BACKGROUND=|#GRUB_BACKGROUND=|' "$DEFAULTS"

"$MKCONFIG" -o "$GRUB_ROOT/grub.cfg"
printf 'JarvOS GRUB theme installed in %s\n' "$DEST"
