#!/usr/bin/env bash
# jarvos-link-commands — a fresh install must put every JarvOS command on PATH.
# Run: tests/jarvos-link-commands.test.sh
set -uo pipefail
# shellcheck source=tests/lib/sandbox.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/sandbox.sh"
# shellcheck source=lib/jarvos-link-commands.sh
source "$REPO_ROOT/lib/jarvos-link-commands.sh"

make_sandbox
trap clean_sandbox EXIT
DEST="$SANDBOX_ROOT/local-bin"

start_test "every bin/ command and the two scripts are linked into the repo"
jarvos_link_commands "$REPO_ROOT" "$DEST"
missing=""
for f in "$REPO_ROOT"/bin/jarvos-* "$REPO_ROOT/scripts/jarvos-sync" "$REPO_ROOT/scripts/jarvos-module-install"; do
    n="$(basename "$f")"
    [[ "$(readlink "$DEST/$n")" == "$f" ]] || missing+=" $n"
done
{ [[ -z "$missing" ]] || fail_test "not linked:$missing"; } && pass_test

start_test "linking twice is harmless and replaces a stale copy with a link"
# Remove the link first: writing through it would overwrite the real command.
rm -f "$DEST/jarvos-update"
printf '#!/bin/sh\necho stale\n' >"$DEST/jarvos-update"
jarvos_link_commands "$REPO_ROOT" "$DEST"
{ [[ -L "$DEST/jarvos-update" ]] || fail_test "stale copy was kept"; } &&
    { head -1 "$REPO_ROOT/bin/jarvos-update" | grep -q bash || fail_test "the real command was overwritten"; } && pass_test

start_test "every command a shipped systemd unit runs is provided"
gaps=""
while IFS= read -r cmd; do
    [[ -e "$DEST/$cmd" ]] || gaps+=" $cmd"
done < <(grep -hoE '(%h/\.local/bin/|/usr/bin/env )jarvos-[A-Za-z0-9-]+' \
    "$REPO_ROOT"/config/.config/systemd/user/*.service | sed -E 's#.*(jarvos-)#\1#' | sort -u)
{ [[ -z "$gaps" ]] || fail_test "units run commands nobody installs:$gaps"; } && pass_test

summary "jarvos-link-commands"
