#!/usr/bin/env bash
# Literal shell syntax is intentional in the IPC argument fixture.
# shellcheck disable=SC2016
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/upstream/bin" "$tmp/upstream/shell" "$tmp/shims"
touch "$tmp/upstream/shell/shell.qml"
export JARVOS_OMARCHY_PATH="$tmp/upstream" TEST_CALLS="$tmp/calls"
cat > "$tmp/upstream/bin/omarchy-shell" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_CALLS"
printf '%s' "${TEST_RESPONSE:-}"
exit "${TEST_EXIT:-0}"
SH
cat > "$tmp/shims/qs" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$TEST_CALLS"
SH
chmod +x "$tmp/upstream/bin/omarchy-shell" "$tmp/shims/qs"
export PATH="$tmp/shims:$PATH"
cli="$repo/bin/jarvos-shell"
"$cli" --help >/dev/null
[[ ! -e "$TEST_CALLS" ]]
printf '  ok   help has no runtime side effects\n'
"$cli" ipc shell summon test.panel '{"text":"spaces and $(false)"}'
printf '%s\n' shell summon test.panel '{"text":"spaces and $(false)"}' > "$tmp/expected"
cmp "$tmp/expected" "$TEST_CALLS"
printf '  ok   IPC preserves literal arguments\n'
status=0
TEST_EXIT=23 "$cli" status >/dev/null 2>&1 || status=$?
[[ $status == 23 ]]
printf '  ok   IPC failure propagates\n'
status=0
TEST_RESPONSE=unknown "$cli" ipc shell summon missing '{}' >/dev/null 2>&1 || status=$?
[[ $status != 0 ]]
printf '  ok   semantic IPC failure propagates\n'
"$cli" start
printf '%s\n' -n -p "$tmp/upstream/shell" > "$tmp/expected"
cmp "$tmp/expected" "$TEST_CALLS"
printf '  ok   start selects the explicit upstream config\n'
status=0
"$cli" theme ../../escape >/dev/null 2>&1 || status=$?
[[ $status != 0 ]]
printf '  ok   theme path traversal is rejected\n'
cat > "$tmp/upstream/bin/omarchy-theme-switcher" <<'SH'
#!/usr/bin/env bash
printf '%s' "${TEST_SELECTION-jarvos}"
SH
cat > "$tmp/upstream/bin/omarchy-theme-set" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$OMARCHY_THEME_HEADLESS:$OMARCHY_THEME_SKIP_BACKGROUND:$1" > "$TEST_THEME"
mkdir -p "$HOME/.local/state/omarchy/current/theme"
touch "$HOME/.local/state/omarchy/current/theme/colors.toml" "$HOME/.local/state/omarchy/current/theme/shell.toml"
SH
chmod +x "$tmp/upstream/bin/omarchy-theme-switcher" "$tmp/upstream/bin/omarchy-theme-set"
export TEST_THEME="$tmp/theme"
HOME="$tmp/home" "$cli" theme
[[ $(cat "$TEST_THEME") == '1:1:jarvos' ]]
printf '  ok   selected theme applies without full-system hooks\n'
rm "$TEST_THEME"
HOME="$tmp/home" TEST_SELECTION='' "$cli" theme
[[ ! -e "$TEST_THEME" ]]
printf '  ok   cancelled theme selection changes nothing\n'
mkdir -p "$tmp/wallpapers" "$tmp/home/.local/state/omarchy/current"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jKf0AAAAASUVORK5CYII=' | base64 -d > "$tmp/wallpapers/image.png"
ln -s "$tmp/wallpapers/image.png" "$tmp/home/.local/state/omarchy/current/background"
cat > "$tmp/upstream/bin/omarchy-menu-images" <<'SH'
#!/usr/bin/env bash
shift
for dir in "$@"; do [[ -d "$dir" ]] || exit 23; done
printf '%s' "$TEST_WALLPAPER"
SH
chmod +x "$tmp/upstream/bin/omarchy-menu-images"
HOME="$tmp/home" TEST_WALLPAPER="$tmp/wallpapers/image.png" "$cli" wallpaper
[[ $(readlink "$tmp/home/.cache/hyprlock-wallpaper") == "$tmp/wallpapers/image.png" ]]
printf '  ok   wallpaper picker receives existing directories and updates Hyprlock\n'
printf 'test_unsupported_video' > "$tmp/wallpapers/video.mp4"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/shims/notify-send"
chmod +x "$tmp/shims/notify-send"
status=0
HOME="$tmp/home" "$cli" wallpaper "$tmp/wallpapers/video.mp4" >/dev/null 2>&1 || status=$?
[[ $status != 0 && $(readlink "$tmp/home/.cache/hyprlock-wallpaper") == "$tmp/wallpapers/image.png" ]]
printf '  ok   invalid wallpaper leaves the Hyprlock image intact\n'
status=0
"$cli" unknown >/dev/null 2>&1 || status=$?
[[ $status == 2 ]]
printf '  ok   unknown commands fail\n'
status=0
JARVOS_OMARCHY_PATH="$tmp/absent" "$cli" status >/dev/null 2>&1 || status=$?
[[ $status != 0 ]]
printf '  ok   missing upstream fails with no alternate shell\n'
