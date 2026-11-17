#!/usr/bin/env bash
# Emit the current lockscreen proverb as a Pango-markup interlinear block
# (A2), or with `png` as the column-true image (A3). Arg: block|png|layout|cn|en|pinyin|tag.
set -euo pipefail
exec python3 "$(dirname "$0")/hanzi.py" "${1:-block}"
