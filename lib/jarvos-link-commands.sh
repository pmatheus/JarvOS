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
