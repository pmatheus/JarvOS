#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ ! -d "$ROOT" ]]; then
    echo "lint-shape-async: directory not found: $ROOT" >&2
    exit 2
fi

mapfile -d '' files < <(find "$ROOT" -type f -name '*.qml' -print0)

if [[ ${#files[@]} -eq 0 ]]; then
    exit 0
fi

violations=$(awk '
    function top() { return depth > 0 ? stack[depth] : "" }
    function emit(file, lineno, why) {
        printf("%s:%d: %s\n", file, lineno, why)
        bad = 1
    }
    function strip_block_comments(s,    out, idx, ce) {
        out = ""
        while ((idx = index(s, "/*")) > 0) {
            out = out substr(s, 1, idx - 1)
            s = substr(s, idx + 2)
            ce = index(s, "*/")
            if (ce == 0) {
                in_block = 1
                return out
            }
            s = substr(s, ce + 2)
        }
        return out s
    }

    FNR == 1 {
        depth = 0
        in_block = 0
        delete stack
    }

    {
        line = $0
        if (in_block) {
            ce = index(line, "*/")
            if (ce == 0) next
            line = substr(line, ce + 2)
            in_block = 0
        }
        line = strip_block_comments(line)
        sub(/\/\/.*/, "", line)

        # Defense in depth: same-line Shape{...asynchronous: true...}.
        # The brace-walker below handles multi-line; this handles the case
        # where the opening Shape{, the property, and the closing } all sit
        # on a single line (which the walker would pop out of before checking).
        if (line ~ /Shape[[:space:]]*\{[^{}]*asynchronous[[:space:]]*:[[:space:]]*true/) {
            emit(FILENAME, FNR, "asynchronous: true inside Shape{} (single-line)")
        }

        # Multi-line walker.
        rest = line
        while (length(rest) > 0) {
            if (match(rest, /([A-Z][A-Za-z0-9_]*)[[:space:]]*\{/)) {
                head = substr(rest, 1, RSTART - 1)
                name = substr(rest, RSTART, RLENGTH)
                n_open = gsub(/\{/, "{", head)
                n_close = gsub(/\}/, "}", head)
                for (i = 0; i < n_close; i++) if (depth > 0) depth--
                for (i = 0; i < n_open; i++) { depth++; stack[depth] = "_anon" }
                ename = name
                sub(/[[:space:]]*\{$/, "", ename)
                depth++
                stack[depth] = ename
                rest = substr(rest, RSTART + RLENGTH)
                continue
            }
            n_open = gsub(/\{/, "{", rest)
            n_close = gsub(/\}/, "}", rest)
            for (i = 0; i < n_open; i++) { depth++; stack[depth] = "_anon" }
            for (i = 0; i < n_close; i++) if (depth > 0) depth--
            break
        }

        if (line ~ /asynchronous[[:space:]]*:[[:space:]]*true/) {
            ctx = top()
            if (ctx == "Shape") {
                emit(FILENAME, FNR, "asynchronous: true inside Shape{}")
            }
        }
    }

    END { exit bad ? 1 : 0 }
' "${files[@]}") || rc=$?

rc=${rc:-0}

if [[ -n "$violations" ]]; then
    echo "$violations" >&2
fi

exit "$rc"
