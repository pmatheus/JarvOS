#!/usr/bin/env bash
# tests/hyprlock-hanzi.test.sh — the lockscreen proverb image keeps every
# column (pinyin / hanzi / gloss) on one axis and fits the hyprlock widget.
set -euo pipefail

# shellcheck source=tests/lib/sandbox.sh
source "$(dirname "$0")/lib/sandbox.sh"

make_sandbox
trap clean_sandbox EXIT

HELPERS="$REPO_ROOT/config/.config/hypr/hyprlock"
CONF="$REPO_ROOT/config/.config/hypr/hyprlock.conf"

start_test "every proverb's rows are centred on their column and fit the canvas"
set +e
out="$(python3 - "$HELPERS" 2>&1 <<'PY'
import sys, cairo
sys.path.insert(0, sys.argv[1])
import hanzi
ctx = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))
bad = []
for p in hanzi.PROVERBS:
    for rows, centre in hanzi.plan(p, ctx):
        for name, (_, w, _) in rows.items():
            left = round(centre - w / 2)
            if abs(left + w / 2 - centre) > 1:
                bad.append(f"{p['cn']} {name} off-axis")
            if left < 0 or left + w > hanzi.CANVAS_W:
                bad.append(f"{p['cn']} {name} outside canvas")
print("BAD:", bad if bad else "none", "proverbs:", len(hanzi.PROVERBS))
sys.exit(1 if bad else 0)
PY
)"
status=$?
set -e
assert_status "$status" 0 &&
    assert_stdout_contains "$out" "BAD: none" &&
    pass_test

start_test "png mode writes a canvas-sized PNG and prints its path"
run="$SANDBOX_ROOT/run"
mkdir -p "$run"
printf '%s\n' '借刀杀人|kill with a borrowed knife' > "$run/hyprlock-proverb"
set +e
out="$(XDG_RUNTIME_DIR="$run" "$HELPERS/hanzi.sh" png 2>&1)"
status=$?
size="$(python3 -c 'import cairo,sys; s=cairo.ImageSurface.create_from_png(sys.argv[1]); print(s.get_width(), s.get_height())' "$run/jarvos-lock-hanzi.png" 2>&1)"
set -e
assert_status "$status" 0 &&
    assert_stdout_contains "$out" "$run/jarvos-lock-hanzi.png" &&
    assert_stdout_contains "$size" "1600 172" &&
    pass_test

start_test "hyprlock image size matches the renderer's canvas height"
canvas_h="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import hanzi; print(hanzi.CANVAS_H)' "$HELPERS")"
conf_h="$(awk '/reload_cmd = .*hanzi.sh png/{f=1} f && /^ *size *=/{print $3; exit}' "$CONF")"
if [[ "$canvas_h" == "$conf_h" ]]; then pass_test; else fail_test "canvas $canvas_h != hyprlock size $conf_h"; fi

summary
