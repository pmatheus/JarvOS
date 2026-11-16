#!/usr/bin/env bash
# jarvos_link_commands BASE DEST — put every JarvOS command on PATH as a link
# into the checkout at BASE. Units call commands by name (jarvos-update-auto,
# jarvos-monitor-layout), so a command left unlinked is a unit that fails on a
# fresh install. Links, not copies, so an update of the checkout is the update
# of the command. A stale copy in DEST is replaced by the link.
jarvos_link_commands() {
    local base="$1" dest="$2" f
    mkdir -p "$dest" || return 1
    for f in "$base"/bin/jarvos-* "$base/scripts/jarvos-sync" "$base/scripts/jarvos-module-install"; do
        [[ -f "$f" && -x "$f" ]] || continue
        ln -sfn "$f" "$dest/$(basename "$f")" || return 1
    done
}

# jarvos_link_shell BASE CONFIG_HOME — make CONFIG_HOME/quickshell/jarvos a
# link into the checkout. The shell is code, not user configuration: as a copy
# it never received what jarvos-update pulled. A copy that differs from the
# checkout is kept aside as jarvos.pre-link-<stamp>; an identical one is
# simply replaced.
jarvos_link_shell() {
    local base="$1" cfg="$2" src dst stamp
    src="$base/config/.config/quickshell/jarvos"
    dst="$cfg/quickshell/jarvos"
    [[ -d "$src" ]] || return 1
    mkdir -p "$cfg/quickshell" || return 1
    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$src" ]] && return 0
        rm -f "$dst"
    elif [[ -d "$dst" ]]; then
        if diff -rq --exclude=__pycache__ --exclude=.ruff_cache "$src" "$dst" >/dev/null 2>&1; then
            rm -rf "$dst"
        else
            stamp="${JARVOS_LINK_STAMP:-$(date +%Y%m%d%H%M%S)}"
            mv "$dst" "$dst.pre-link-$stamp" || return 1
        fi
    fi
    ln -sfn "$src" "$dst"
}
