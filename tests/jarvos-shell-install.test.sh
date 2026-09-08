#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.local/share/omarchy/"{.git,shell,themes,default/fonts/omarchy} "$tmp/bin"
touch "$tmp/home/.local/share/omarchy/shell/shell.qml" "$tmp/home/.local/share/omarchy/default/fonts/omarchy/omarchy.ttf"
export TEST_REVISION
TEST_REVISION=$(cat "$repo/share/jarvos/omarchy/upstream.commit")
cat > "$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
if [[ $3 == rev-parse ]]; then printf '%s\n' "$TEST_REVISION"; fi
SH
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/fc-cache"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/hyprctl"
chmod +x "$tmp/bin/"*
mkdir -p "$tmp/emptyhome/.local/share"
cp -a "$tmp/home/.local/share/omarchy" "$tmp/emptyhome/.local/share/"
HOME="$tmp/emptyhome" PATH="$tmp/bin:$PATH" "$repo/bin/jarvos-shell-install" --prepare >/dev/null
[[ -f "$tmp/emptyhome/.config/omarchy/shell.json" ]]
printf '  ok   prepare accepts HOME without any previous integration files\n'
mkdir -p "$tmp/home/.config/hypr/hyprland"
printf '%s\n' 'exec-once = my-personal-app' 'exec-once = awww-daemon --format xrgb' > "$tmp/home/.config/hypr/hyprland/execs.conf"
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$repo/bin/jarvos-shell-install" --prepare >/dev/null
first_backup=$(cat "$tmp/home/.local/state/jarvos/omarchy-migration/latest")
[[ -f "$tmp/home/.local/state/omarchy/current/theme/colors.toml" ]]
printf '  ok   prepare initializes a theme without a running desktop\n'
[[ $(cat "$tmp/home/.config/hypr/hyprland/execs.conf") == 'exec-once = my-personal-app' ]]
printf '  ok   conflicting wallpaper startup removed, personal startup kept\n'
printf '{"version":1,"custom":"preserve-me"}\n' > "$tmp/home/.config/omarchy/shell.json"
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$repo/bin/jarvos-shell-install" --prepare >/dev/null
jq -e '.custom=="preserve-me"' "$tmp/home/.config/omarchy/shell.json" >/dev/null
backup=$(cat "$tmp/home/.local/state/jarvos/omarchy-migration/latest")
[[ -f "$backup/config.tar.gz" ]]
printf '  ok   repeated preparation keeps user preferences and a backup\n'
before=$(sha256sum "$tmp/home/.config/omarchy/shell.json")
status=0
HOME="$tmp/home" PATH="$tmp/bin:$PATH" TEST_REVISION=wrong "$repo/bin/jarvos-shell-install" --prepare >/dev/null 2>&1 || status=$?
[[ $status != 0 && "$before" == "$(sha256sum "$tmp/home/.config/omarchy/shell.json")" ]]
printf '  ok   wrong revision leaves preferences untouched\n'
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$repo/bin/jarvos-shell-install" --rollback "$first_backup"
[[ ! -e "$tmp/home/.config/omarchy" ]]
archived_configs=("$first_backup/after-rollback/"*/.config/omarchy/shell.json)
[[ -f "${archived_configs[0]}" ]]
rg -q 'awww-daemon' "$tmp/home/.config/hypr/hyprland/execs.conf"
printf '  ok   rollback restores startup and archives newly created preferences\n'
cat > "$tmp/bin/systemctl" <<'SH'
#!/usr/bin/env bash
[[ $2 != restart ]]
SH
status=0
HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$repo/bin/jarvos-shell-install" --activate >/dev/null 2>&1 || status=$?
[[ $status != 0 && ! -e "$tmp/home/.config/omarchy" ]]
rg -q 'awww-daemon' "$tmp/home/.config/hypr/hyprland/execs.conf"
printf '  ok   failed service activation rolls back automatically\n'
