#!/bin/bash
# Spotlight Indexer — builds and maintains a pre-built index for spotlight.sh
# Runs as a systemd user service. Watches filesystem for changes via inotifywait.

CACHE_DIR="$HOME/.cache/spotlight"
INDEX_FILE="$CACHE_DIR/index.txt"
TIMESTAMP_FILE="$CACHE_DIR/last-update"
LOCK_FILE="$CACHE_DIR/indexer.lock"

SEARCH_DIRS=("$HOME" "$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop" "$HOME/work" "$HOME/Projects" "$HOME/Pictures" "$HOME/Music" "$HOME/Videos")
EXCLUDE_DIRS=(.git node_modules .cache .local/share .mozilla .config/chromium .config/google-chrome __pycache__ .venv .env target build dist .next .nuxt)
MAX_DEPTH=5

mkdir -p "$CACHE_DIR"

# Cleanup lock on exit
cleanup() {
    rm -f "$LOCK_FILE"
    # Kill all child processes (inotifywait etc)
    kill 0 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

# ── Index building ──────────────────────────────────────────────────────────

build_apps_index() {
    local apps=""
    for dir in /usr/share/applications "$HOME/.local/share/applications"; do
        if [ -d "$dir" ]; then
            apps="$apps$(ls "$dir"/*.desktop 2>/dev/null | xargs -I{} basename {} .desktop)"$'\n'
        fi
    done
    echo "$apps" | sort -u | sed '/^$/d' | sed 's/^/[app] /'
}

build_files_index() {
    local exclude_args=()
    for exc in "${EXCLUDE_DIRS[@]}"; do
        exclude_args+=(--exclude "$exc")
    done

    # Filter to only existing search dirs
    local existing_dirs=()
    for d in "${SEARCH_DIRS[@]}"; do
        [ -d "$d" ] && existing_dirs+=("$d")
    done
    [ ${#existing_dirs[@]} -eq 0 ] && return

    local entries
    if command -v fd >/dev/null 2>&1; then
        entries=$(fd . "${existing_dirs[@]}" --max-depth "$MAX_DEPTH" "${exclude_args[@]}" 2>/dev/null)
    else
        local find_excludes=()
        for exc in "${EXCLUDE_DIRS[@]}"; do
            find_excludes+=(-not -path "*/$exc/*")
        done
        entries=$(find "${existing_dirs[@]}" -maxdepth "$MAX_DEPTH" "${find_excludes[@]}" 2>/dev/null)
    fi

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        if [ -d "$entry" ]; then
            echo "[folder] $entry"
        else
            echo "[file] $entry"
        fi
    done <<< "$entries"
}

build_full_index() {
    echo "[indexer] Building full index..." >&2
    local tmpfile
    tmpfile=$(mktemp "$CACHE_DIR/index.tmp.XXXXXX")

    {
        build_apps_index
        build_files_index
    } | sort -u > "$tmpfile"

    mv -f "$tmpfile" "$INDEX_FILE"
    date -Iseconds > "$TIMESTAMP_FILE"
    echo "[indexer] Index built: $(wc -l < "$INDEX_FILE") entries" >&2
}

# ── Initial full build ──────────────────────────────────────────────────────

build_full_index

# ── Watch for filesystem changes and rebuild with debounce ──────────────────

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "[indexer] inotifywait not found, running in one-shot mode" >&2
    # Sleep forever to keep the service alive; rely on restarts for refresh
    exec sleep infinity
fi

# Build the list of existing watch directories
WATCH_DIRS=()
for d in "${SEARCH_DIRS[@]}"; do
    [ -d "$d" ] && WATCH_DIRS+=("$d")
done

# Also watch desktop file directories for app changes
for d in /usr/share/applications "$HOME/.local/share/applications"; do
    [ -d "$d" ] && WATCH_DIRS+=("$d")
done

if [ ${#WATCH_DIRS[@]} -eq 0 ]; then
    echo "[indexer] No directories to watch, sleeping" >&2
    exec sleep infinity
fi

# Build exclude regex for inotifywait
EXCLUDE_REGEX="/($(IFS='|'; echo "${EXCLUDE_DIRS[*]}"))/|/\."

echo "[indexer] Watching ${#WATCH_DIRS[@]} directories for changes..." >&2

DEBOUNCE_PID=""

debounced_rebuild() {
    # Kill previous pending rebuild if any
    if [ -n "$DEBOUNCE_PID" ] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null
        wait "$DEBOUNCE_PID" 2>/dev/null
    fi

    (
        sleep 2
        build_full_index
    ) &
    DEBOUNCE_PID=$!
}

# Monitor for CREATE, DELETE, MOVED_FROM, MOVED_TO events
inotifywait \
    --recursive \
    --monitor \
    --event create \
    --event delete \
    --event moved_from \
    --event moved_to \
    --exclude "$EXCLUDE_REGEX" \
    --format '%e %w%f' \
    "${WATCH_DIRS[@]}" 2>/dev/null |
while IFS= read -r event_line; do
    debounced_rebuild
done
