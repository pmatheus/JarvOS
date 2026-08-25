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
