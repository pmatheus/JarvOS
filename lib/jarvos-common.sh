# shellcheck shell=bash
# Shared resolution for every jarvos-* command. Sourced, never executed.
#
# JARVOS_PATH  the runtime tree: a git checkout in development, and
#              /usr/share/jarvos once packaged. Derived from where THIS file
#              sits, so there is exactly one thing to get right.
# JARVOS_STATE per-user runtime state: markers, migration bookkeeping.

_jarvos_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JARVOS_PATH="${JARVOS_PATH:-$(dirname "$_jarvos_lib_dir")}"
JARVOS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/jarvos"
export JARVOS_PATH JARVOS_STATE
unset _jarvos_lib_dir

die() {
    printf '%s: %s\n' "${0##*/}" "$1" >&2
    exit "${2:-1}"
}

# EX_TEMPFAIL. An update step exits with this when the failure is the
# network's, not the machine's: waiting is the remedy, so nothing downstream
# should try to repair or roll back over it.
# shellcheck disable=SC2034  # read by the commands that source this file
JARVOS_EX_TEMPFAIL=75

# jarvos_network_failure <log> — did this output fail on the network?
jarvos_network_failure() {
    grep -qiE 'could not resolve host|failed retrieving file|failed to synchronize all databases|unable to access .*: Could not|Connection timed out|Temporary failure in name resolution|network is unreachable' "$1" 2>/dev/null
}

# jarvos_pacman_unlock_stale — remove a db.lck nothing alive could own.
#
# An interrupted pacman leaves its lock behind, and every later transaction
# refuses to start over it. It is only stale when no package manager is
# running; with one running, the lock is real and this returns 1.
#
# Seams: JARVOS_PACMAN_LOCK
jarvos_pacman_unlock_stale() {
    local lock="${JARVOS_PACMAN_LOCK:-/var/lib/pacman/db.lck}"
    [[ -e "$lock" ]] || return 0
    if pgrep -x 'pacman|yay|paru|makepkg|pacman-key' >/dev/null 2>&1; then
        echo "jarvos: pacman is locked by a running package manager" >&2
        return 1
    fi
    echo "jarvos: removing a stale pacman lock (no package manager is running)"
    sudo rm -f "$lock"
}
