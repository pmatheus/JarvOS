#!/usr/bin/env bash
# tests/plymouth-theme.test.sh — the JarvOS Plymouth theme is complete and
# plymouth/install-theme.sh wires it in only where it is safe.
set -euo pipefail

# shellcheck source=tests/lib/sandbox.sh
source "$(dirname "$0")/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

THEME="$REPO_ROOT/plymouth/jarvos/theme"
INSTALL="$REPO_ROOT/plymouth/install-theme.sh"

start_test "every image the script loads exists and is an 8-bit PNG"
missing=""
while IFS= read -r img; do
    f="$THEME/$img"
    if [[ ! -f "$f" ]] || [[ "$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')" != "89504e470d0a1a0a" ]]; then
        missing+=" $img"
    fi
done < <(grep -oE 'Image\("[^"]+"\)' "$THEME/jarvos.script" | sed -E 's/Image\("([^"]+)"\)/\1/' | sort -u)
if [[ -z "$missing" ]]; then pass_test; else fail_test "missing or not PNG:$missing"; fi

start_test "sprites created inside functions are kept in globals"
# A Sprite assigned to a function-local is destroyed when the function returns
# (the password dots vanished that way); bullets must live in global.bullets.
if grep -qE '^\s+if \(!global\.bullets\[i\]\) global\.bullets\[i\] = Sprite' "$THEME/jarvos.script"; then
    pass_test
else
    fail_test "bullet sprites are not global"
fi

setup_fakes() {   # setup_fakes DIR HOOKS-LINE
    mkdir -p "$1/bin" "$1/themes"
    printf '%s\n' "$2" > "$1/mkinitcpio.conf"
    printf 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"\n' > "$1/grub"
    for tool in set-theme mkinitcpio mkconfig; do
        printf '#!/bin/sh\necho "%s $*" >> "%s/calls.log"\n' "$tool" "$1" > "$1/bin/$tool"
        chmod +x "$1/bin/$tool"
    done
}
run_install() {   # run_install DIR
    JARVOS_PLYMOUTH_THEMES="$1/themes" JARVOS_MKINITCPIO_CONF="$1/mkinitcpio.conf" \
        JARVOS_GRUB_DEFAULTS="$1/grub" JARVOS_GRUB_CFG="$1/grub.cfg" \
        JARVOS_PLYMOUTH_SET_THEME="$1/bin/set-theme" JARVOS_MKINITCPIO="$1/bin/mkinitcpio" \
        JARVOS_GRUB_MKCONFIG="$1/bin/mkconfig" "$INSTALL" >/dev/null 2>&1
}

start_test "systemd config: hook added once after systemd, splash added once"
d="$SANDBOX_ROOT/sd"
setup_fakes "$d" "HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)"
run_install "$d" && run_install "$d"
hooks="$(cat "$d/mkinitcpio.conf")"
if [[ "$hooks" == "HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)" ]] &&
    [[ "$(cat "$d/grub")" == 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"' ]] &&
    [[ -f "$d/themes/jarvos/jarvos.script" ]] &&
    grep -q "^set-theme jarvos" "$d/calls.log" && grep -q "^mkinitcpio -P" "$d/calls.log"; then
    pass_test
else
    fail_test "hooks: $hooks / grub: $(cat "$d/grub")"
fi

start_test "busybox encrypt config is left without plymouth"
d="$SANDBOX_ROOT/bb"
setup_fakes "$d" "HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)"
run_install "$d"
if grep -q plymouth "$d/mkinitcpio.conf"; then fail_test "plymouth added to a busybox config"; else pass_test; fi

summary
