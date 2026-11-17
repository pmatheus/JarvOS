#!/usr/bin/env bash
# tests/grub-theme.test.sh — the JarvOS GRUB theme is complete, GRUB can read
# its images, and install-theme.sh sets /etc/default/grub idempotently.
set -euo pipefail

# shellcheck source=tests/lib/sandbox.sh
source "$(dirname "$0")/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

THEME="$REPO_ROOT/grub/jarvos/theme"
INSTALL="$REPO_ROOT/grub/install-theme.sh"

start_test "every file theme.txt names exists, and every PNG is 8-bit RGB/RGBA"
set +e
out="$(python3 - "$THEME" 2>&1 <<'PY'
import pathlib, re, struct, sys
theme = pathlib.Path(sys.argv[1])
txt = (theme / "theme.txt").read_text()
bad = []
for ref in re.findall(r'(?:file|desktop-image|pixmap_style|_style)\s*[:=]\s*"([^"]+)"', txt):
    hits = list(theme.glob(ref)) if "*" in ref else [theme / ref]
    if not hits or not all(h.exists() for h in hits):
        bad.append(f"missing {ref}")
for png in theme.rglob("*.png"):
    head = png.read_bytes()[:26]
    depth, ctype = head[24], head[25]
    if depth != 8 or ctype not in (2, 6):   # GRUB skips anything else silently
        bad.append(f"{png.name} depth={depth} colour-type={ctype}")
for font in re.findall(r'font[a-z_-]*\s*[:=]\s*"([^"]+)"', txt):
    names = []
    for pf2 in theme.glob("*.pf2"):
        d = pf2.read_bytes(); i = 0
        while i < len(d):
            tag, ln = d[i:i+4], struct.unpack(">I", d[i+4:i+8])[0]
            if tag == b"NAME":
                names.append(d[i+8:i+8+ln].rstrip(b"\0").decode()); break
            i += 8 + ln
    if font not in names:
        bad.append(f"font {font!r} not in {names}")
print("BAD:", bad if bad else "none")
sys.exit(1 if bad else 0)
PY
)"
status=$?
set -e
assert_status "$status" 0 && assert_stdout_contains "$out" "BAD: none" && pass_test

start_test "install-theme.sh installs the theme and sets the GRUB keys once"
root="$SANDBOX_ROOT/boot/grub"
defaults="$SANDBOX_ROOT/default-grub"
mkdir -p "$root/themes/Old"
cat > "$defaults" <<'CFG'
GRUB_DEFAULT=0
GRUB_DISTRIBUTOR="Arch"
GRUB_GFXMODE=2560x1440,auto
#GRUB_THEME="/path/to/gfxtheme"
GRUB_BACKGROUND="/boot/grub/themes/Old/background.jpg"
CFG
printf '#!/bin/sh\necho "$@" >> "%s/mkconfig.log"\n' "$SANDBOX_ROOT" > "$SANDBOX_ROOT/mkconfig"
chmod +x "$SANDBOX_ROOT/mkconfig"
set +e
for _ in 1 2; do
    out="$(JARVOS_GRUB_ROOT="$root" JARVOS_GRUB_DEFAULTS="$defaults" \
        JARVOS_GRUB_MKCONFIG="$SANDBOX_ROOT/mkconfig" "$INSTALL" 2>&1)"
    status=$?
done
set -e
conf="$(cat "$defaults")"
if [[ "$status" == 0 && -f "$root/themes/jarvos/theme.txt" ]] &&
    [[ "$conf" == *"GRUB_THEME=\"$root/themes/jarvos/theme.txt\""* ]] &&
    [[ "$conf" == *'GRUB_GFXMODE="1920x1080,auto"'* && "$conf" == *'GRUB_DISTRIBUTOR="JarvOS"'* ]] &&
    [[ "$conf" == *'#GRUB_BACKGROUND='* ]] &&
    [[ "$(grep -c '^GRUB_THEME=' "$defaults")" == 1 && "$(grep -c '^GRUB_GFXMODE=' "$defaults")" == 1 ]] &&
    [[ "$(wc -l < "$SANDBOX_ROOT/mkconfig.log")" == 2 ]]; then
    pass_test
else
    fail_test "status $status; defaults: $(tr '\n' ' ' < "$defaults"); out: $out"
fi

summary
