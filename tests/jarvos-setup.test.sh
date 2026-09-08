#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" JARVOS_FIRST_RUN_MARKER="$tmp/pending"
export TEST_CALLS="$tmp/calls"
mkdir -p "$tmp/bin" "$HOME"
cat > "$tmp/bin/jarvos-shell" <<'SH'
#!/usr/bin/env bash
[[ $1 == status ]] && { echo ok; exit 0; }
printf '%s\n' "$@" > "$TEST_CALLS"
SH
chmod +x "$tmp/bin/jarvos-shell"
export PATH="$tmp/bin:$PATH"
"$repo/bin/jarvos-setup" --first-run
[[ ! -e "$TEST_CALLS" ]]
printf '  ok   existing installations do not open first-run setup\n'
touch "$JARVOS_FIRST_RUN_MARKER"
"$repo/bin/jarvos-setup" --first-run
printf '%s\n' ipc shell summon omarchy.menu '{"menu":"jarvos-setup"}' > "$tmp/expected"
cmp "$TEST_CALLS" "$tmp/expected"
printf '  ok   fresh installations open the native setup menu\n'
"$repo/bin/jarvos-setup" --done
rm "$TEST_CALLS"
"$repo/bin/jarvos-setup" --first-run
[[ ! -e "$TEST_CALLS" ]]
printf '  ok   completed setup does not open again\n'
