#!/usr/bin/env bash
# JarvOS secret-scan: hard gate before committing/pushing a public repo.
# Scans staged content (or all tracked files with --all) for secret-shaped
# strings and private host details. Exit 1 on any hit.
#
# Used by .githooks/pre-commit. Run manually: scripts/secret-scan.sh --all
set -uo pipefail
cd "$(dirname "$0")/.."

staged=false
if [[ "${1:-}" == "--all" ]]; then
    mapfile -t files < <(git ls-files)
elif [[ $# -gt 0 ]]; then
    files=("$@")
else
    staged=true
    mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM)
fi
[[ ${#files[@]} -eq 0 ]] && exit 0

# patterns: real secrets and private identifiers. Tuned to avoid theme/color
# false positives (hex colors, rgba()).
patterns=(
    'AKIA[0-9A-Z]{16}'                         # AWS access key
    'gh[pousr]_[A-Za-z0-9]{20,}'               # GitHub token
    'sk-[A-Za-z0-9]{20,}'                      # OpenAI-style key
    'xox[baprs]-[A-Za-z0-9-]{10,}'             # Slack token
    'BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY'
    '(api[_-]?key|secret|password|passwd|token)["'\'' ]*[:=][ ]*["'\''][A-Za-z0-9/+_-]{12,}["'\'']'  # key = "literal"
    'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'   # JWT
)

hits=0
# Scan what is being COMMITTED, not what happens to sit in the worktree: an index
# staler than the working tree would otherwise sail through with the very content
# the hook exists to stop.
content() {
    if $staged; then git show ":$1" 2>/dev/null; else cat -- "$1" 2>/dev/null; fi
}

for f in "${files[@]}"; do
    $staged || [[ -f "$f" ]] || continue
    case "$f" in *.png|*.jpg|*.jpeg|*.svg|*.gif|*.ttf|*.otf|*.woff*|*.zip|*.tar*) continue;; esac
    for p in "${patterns[@]}"; do
        if content "$f" | grep -nEI "$p" 2>/dev/null | grep -vE '\.example:|\.template:|EXAMPLE|placeholder|<your-' ; then
            echo "  ^ in $f (pattern: $p)"; hits=$((hits+1))
        fi
    done
done

if [[ $hits -gt 0 ]]; then
    echo
    echo "✗ secret-scan: $hits potential secret(s) found. Refusing. Redact or add to .gitignore."
    exit 1
fi
echo "✓ secret-scan: clean (${#files[@]} files)"
