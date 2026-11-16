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

start_test "the shell becomes a link into the checkout, keeping a differing copy aside"
CFG="$SANDBOX_ROOT/config"
mkdir -p "$CFG/quickshell/jarvos"
echo "local edit" >"$CFG/quickshell/jarvos/shell.qml"
JARVOS_LINK_STAMP=20260101 jarvos_link_shell "$REPO_ROOT" "$CFG"
{ [[ "$(readlink "$CFG/quickshell/jarvos")" == "$REPO_ROOT/config/.config/quickshell/jarvos" ]] ||
    fail_test "shell is not a link: $(ls -la "$CFG/quickshell")"; } &&
    { grep -q "local edit" "$CFG/quickshell/jarvos.pre-link-20260101/shell.qml" ||
        fail_test "the differing copy was not kept"; } &&
    { [[ "$(head -c 20 "$REPO_ROOT/config/.config/quickshell/jarvos/shell.qml")" != "local edit" ]] ||
        fail_test "the checkout was overwritten"; } && pass_test

start_test "linking the shell again is a no-op"
JARVOS_LINK_STAMP=20260102 jarvos_link_shell "$REPO_ROOT" "$CFG"
{ [[ ! -e "$CFG/quickshell/jarvos.pre-link-20260102" ]] || fail_test "a link was backed up"; } &&
    { [[ -L "$CFG/quickshell/jarvos" ]] || fail_test "link lost"; } && pass_test

start_test "an identical copy is replaced without a backup"
CFG2="$SANDBOX_ROOT/config2"; mkdir -p "$CFG2/quickshell"
cp -r "$REPO_ROOT/config/.config/quickshell/jarvos" "$CFG2/quickshell/jarvos"
JARVOS_LINK_STAMP=20260103 jarvos_link_shell "$REPO_ROOT" "$CFG2"
{ [[ -L "$CFG2/quickshell/jarvos" ]] || fail_test "not linked"; } &&
    { [[ ! -e "$CFG2/quickshell/jarvos.pre-link-20260103" ]] || fail_test "needless backup"; } && pass_test

summary "jarvos-link-commands"
