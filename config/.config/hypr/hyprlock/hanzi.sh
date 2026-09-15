#!/usr/bin/env bash
# Emit the current lockscreen proverb as a Pango-markup interlinear block
# (A2 — Calligraphic Interlinear). Optional arg: block|cn|en|pinyin|tag.
set -euo pipefail
exec python3 "$(dirname "$0")/hanzi.py" "${1:-block}"
