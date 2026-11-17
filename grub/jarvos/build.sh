#!/usr/bin/env bash
# grub/jarvos/build.sh — regenerate the JarvOS GRUB theme assets.
#
# Dev-time only: needs rsvg-convert, magick, grub-mkfont and the Gabarito and
# JetBrains Mono fonts. The outputs are committed, so installing the theme
# (grub/install-theme.sh) never depends on the target's fonts.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BRAND="$HERE/../../brand"
OUT="$HERE/theme"
INK_LIGHT="#e6e8ee"
mkdir -p "$OUT/icons"

font_file() { fc-match -f '%{file}' "$1"; }
mkfont() {   # mkfont <out-name> <fontconfig pattern> <size> <name used in theme.txt>
    # Latin, Latin-1, general punctuation and arrows only: the full Nerd Font
    # would make a multi-megabyte .pf2 that GRUB loads on every boot.
    grub-mkfont -s "$3" -r 0x20-0x7E,0xA0-0xFF,0x2010-0x2027,0x2190-0x2193,0x23CE-0x23CE \
        -n "$4" -o "$OUT/$1.pf2" "$(font_file "$2")"
}
mkfont gabarito-regular-22  "Gabarito:style=Regular"  22 "Gabarito"
mkfont gabarito-semibold-22 "Gabarito:style=SemiBold" 22 "Gabarito SemiBold"
mkfont jetbrainsmono-14     "JetBrainsMono NF:style=Regular" 14 "JetBrains Mono"

css="$(mktemp --suffix=.css)"; trap 'rm -f "$css"' EXIT
printf 'svg { color: %s; }\n' "$INK_LIGHT" > "$css"
# Lockup above the menu, and the tile as the entry icon.
rsvg-convert --stylesheet "$css" -w 352 "$BRAND/jarvos-lockup.svg" -o "$OUT/lockup.png"
rsvg-convert --stylesheet "$css" -w 32 "$BRAND/jarvos-mark.svg" -o "$OUT/icons/jarvos.png"
# GRUB's PNG reader takes only 8-bit RGB/RGBA: grey+alpha or 16-bit files are
# skipped without a word, so every asset is forced to PNG32.
png32() { magick "$1" -depth 8 "PNG32:$1"; }
png32 "$OUT/lockup.png"; png32 "$OUT/icons/jarvos.png"
# Rescue entry: the same tile, dimmed, so it reads as secondary.
magick "$OUT/icons/jarvos.png" -channel A -fx 'a*0.42' +channel -depth 8 "PNG32:$OUT/icons/rescue.png"

# Background: flat ink. A gradient this dark bands visibly at 8 bits per channel.
magick -size 1920x1080 xc:'#0d0f13' -depth 8 "PNG24:$OUT/background.png"

# Selected-item highlight, 9-slice. GRUB draws the corner slices outside the
# item box, so r is also how far the pill overhangs (keep item_spacing > 2r).
r=10; s=$((2 * r + 1))
magick -size ${s}x${s} xc:none -fill 'rgba(255,255,255,0.075)' -stroke 'rgba(255,255,255,0.13)' \
    -strokewidth 1 -draw "roundrectangle 0.5,0.5 $((s - 1)).5,$((s - 1)).5 $r,$r" "$OUT/.sel.png"
crop() { magick "$OUT/.sel.png" -crop "$1" +repage -depth 8 "PNG32:$OUT/select_$2.png"; }
crop ${r}x${r}+0+0 nw;        crop 1x${r}+${r}+0 n;        crop ${r}x${r}+$((r + 1))+0 ne
crop ${r}x1+0+${r} w;         crop 1x1+${r}+${r} c;        crop ${r}x1+$((r + 1))+${r} e
crop ${r}x${r}+0+$((r + 1)) sw; crop 1x${r}+${r}+$((r + 1)) s; crop ${r}x${r}+$((r + 1))+$((r + 1)) se
# Unselected items get a transparent frame of the same size: GRUB shifts an
# item's text by its frame's border, so without it the selected row drops r px.
for slice in "$OUT"/select_*.png; do
    magick "$slice" -alpha transparent -depth 8 "PNG32:${slice/select_/item_}"
done
rm -f "$OUT/.sel.png"
echo "built $(find "$OUT" -type f | wc -l) files in $OUT"
