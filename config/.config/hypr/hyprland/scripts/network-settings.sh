#!/usr/bin/env bash
# Network settings launcher for JarvOS.
# Opens nm-connection-editor (full NetworkManager GUI) and, on close, re-applies
# the edited profiles to the running devices so saved changes take effect live
# without a connectivity drop. NetworkManager stays the single source of truth,
# so the topbar network widget (services/Nmcli.qml, 4s poll) reflects edits
# automatically.

set -u

notify() { command -v notify-send >/dev/null && notify-send -a "Network" "$@" || true; }

if ! command -v nm-connection-editor >/dev/null; then
    notify "Network settings" "nm-connection-editor is not installed"
    exit 1
fi

# GTK app — make sure it talks to the running NetworkManager session.
nm-connection-editor "$@"

# Apply saved edits to live devices. `device reapply` re-reads the connection
# profile and applies the diff in place (no down/up), so the link does not drop.
applied=0
while IFS=: read -r dev type state; do
    case "$type" in
        ethernet|wifi)
            [ "$state" = "connected" ] || continue
            nmcli device reapply "$dev" >/dev/null 2>&1 && applied=1
            ;;
    esac
done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null)

[ "$applied" = 1 ] && notify "Network settings" "Applied changes to active connection(s)"
exit 0
