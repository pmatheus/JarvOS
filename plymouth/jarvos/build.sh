#!/usr/bin/env bash
# plymouth/jarvos/build.sh — regenerate the JarvOS Plymouth theme images.
#
# Dev-time only (rsvg-convert, magick, Gabarito and JetBrains Mono). Text is
# baked into images so the initramfs needs no fonts; the outputs are committed.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BRAND="$HERE/../../brand"
OUT="$HERE/theme"
mkdir -p "$OUT"
font() { fc-match -f '%{file}' "$1"; }
text() {   # text <out> <font pattern> <px> <colour> <string>
    magick -background none -fill "$4" -font "$(font "$2")" -pointsize "$3" \
        label:"$5" -trim +repage -bordercolor none -border 2 -depth 8 "PNG32:$OUT/$1"
}
css="$(mktemp --suffix=.css)"; trap 'rm -f "$css"' EXIT
printf 'svg { color: #e6e8ee; }\n' > "$css"
rsvg-convert --stylesheet "$css" -w 300 "$BRAND/jarvos-lockup.svg" -o "$OUT/lockup.png"
magick "$OUT/lockup.png" -depth 8 "PNG32:$OUT/lockup.png"

text prompt.png "Gabarito:style=Medium" 20 '#c0c8d0' "Disk password"
text hint.png "JetBrainsMono NF:style=Regular" 13 '#6b707a' "automatic unlock unavailable — type it to continue"

# Password field: same shape as the lockscreen input (radius 14).
magick -size 340x46 xc:none -fill 'rgba(255,255,255,0.05)' -stroke 'rgba(255,255,255,0.14)' \
    -strokewidth 1 -draw "roundrectangle 0.5,0.5 339.5,45.5 14,14" -depth 8 "PNG32:$OUT/field.png"
magick -size 10x10 xc:none -fill '#f5f7fa' -draw "circle 4.5,4.5 4.5,0.5" -depth 8 "PNG32:$OUT/bullet.png"
# Boot progress hairline.
magick -size 1x1 xc:'#262a33' -depth 8 "PNG32:$OUT/track.png"
magick -size 1x1 xc:'#e6e8ee' -depth 8 "PNG32:$OUT/fill.png"
echo "built $(find "$OUT" -name '*.png' | wc -l) images in $OUT"
