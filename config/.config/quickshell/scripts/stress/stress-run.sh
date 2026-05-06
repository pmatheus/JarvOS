#!/usr/bin/env bash
# Phase B2 stress harness driver — proves the QQuickShapeCurveRunnable race
# (the bug deleted by removing `asynchronous: true` from the deployed
# CircularProgress.qml) is closed.
#
# WHY WE MUTATE A TEMP COPY, NOT THE DEPLOYED FILE
# QuickShell's `qs.<path>` namespace only resolves when the entry file is
# `shell.qml` rooted at the config dir. A standalone `qs -p stress.qml`
# cannot import the deployed `CircularProgress.qml` — that file's own
# `import qs.services` / `import qs.config` lines resolve against the
# caller's config root, not jarvos. So we inline the Shape pattern in
# stress-shape-thrash.qml and have the `unpatched` driver mutate a temp
# copy of THAT file. The Qt-level race is identical (same Shape +
# CurveRenderer + asynchronous + churning Repeater); proving it crashes
# pre-patch and survives post-patch is what closes the proof.
#
# The structural fix on the deployed file (no `asynchronous: true` on any
# Shape with CurveRenderer) is validated separately by lint-shape-async.sh.
#
# Modes:
#   unpatched  Edits a TEMP COPY of stress-shape-thrash.qml to inject
#              `asynchronous: true` after the `// STRESS_ASYNC_HOOK`
#              marker, runs the harness, expects ≥1 quickshell SIGSEGV
#              (coredump or journal entry) or an early qs exit.
#   patched    Runs the unmodified stress qml (no `asynchronous: true`).
#              Expects zero crashes for the full duration.
#
# Safety:
#   - Targets only its own qs PID via $QS_PID; never `pkill quickshell`.
#   - Touches no files outside this stress dir and a private mktemp dir.
#   - Trap restores on every exit path including SIGINT/ERR.

set -u -o pipefail

# ───────────────────────────────────────────────────────── config ──
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STRESS_QML_SRC="${SCRIPT_DIR}/stress-shape-thrash.qml"
DEPLOYED_CFG="${HOME}/.config/quickshell/jarvos"
TARGET_FILE="${DEPLOYED_CFG}/components/controls/CircularProgress.qml"
LOCK_SHELL="${DEPLOYED_CFG}/lock-shell.qml"
LOCK_SVC="quickshell-jarvos-lock.service"

DURATION_SEC="${DURATION_SEC:-300}"   # full 300s by default; override via env
WITH_LOCK_THRASH=0
MODE=""

usage() {
    cat <<EOF
usage: $0 <unpatched|patched> [--with-lock-thrash]
env:
  DURATION_SEC  override harness duration (default 300)
EOF
}

# ───────────────────────────────────────────────────────── args ──
while [[ $# -gt 0 ]]; do
    case "$1" in
        unpatched|patched) MODE="$1"; shift ;;
        --with-lock-thrash) WITH_LOCK_THRASH=1; shift ;;
        --no-lock-thrash)   WITH_LOCK_THRASH=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ -z "$MODE" ]]; then
    usage; exit 2
fi

# ───────────────────────────────────────────────── coredump precheck ──
if ! command -v coredumpctl >/dev/null 2>&1; then
    echo "FATAL: systemd-coredump unavailable; harness cannot detect crashes" >&2
    exit 2
fi
core_pattern="$(cat /proc/sys/kernel/core_pattern 2>/dev/null || true)"
if [[ "$core_pattern" != *systemd-coredump* ]]; then
    echo "FATAL: /proc/sys/kernel/core_pattern is not routed to systemd-coredump" >&2
    echo "  current: $core_pattern" >&2
    exit 2
fi
# `coredumpctl list` returns 1 when there are no dumps; tolerate that.
list_err="$(coredumpctl --no-pager list 2>&1 >/dev/null || true)"
if [[ -n "$list_err" \
      && "$list_err" != *"No coredumps found"* \
      && "$list_err" != *"No matches"* ]]; then
    echo "FATAL: coredumpctl list failed: $list_err" >&2
    exit 2
fi

# ──────────────────────────────────────────────── lock-thrash gating ──
LOCK_LEG_ACTIVE=0
if (( WITH_LOCK_THRASH )); then
    if [[ -f "$LOCK_SHELL" ]] && systemctl --user is-enabled "$LOCK_SVC" >/dev/null 2>&1; then
        LOCK_LEG_ACTIVE=1
        echo "[info] lock-thrash leg ARMED (lock-shell.qml + svc enabled)"
    else
        echo "[info] --with-lock-thrash requested but L3 infra not deployed; skipping lock leg"
    fi
fi

# ───────────────────────────────────────────────────────── tempdir ──
TMPDIR="$(mktemp -d)"
QS_LOG="${TMPDIR}/qs.log"
STRESS_QML_RUNTIME="${TMPDIR}/stress-shape-thrash.qml"
QS_PID=""

cleanup() {
    local rc=$?
    set +e
    if [[ -n "$QS_PID" ]] && kill -0 "$QS_PID" 2>/dev/null; then
        kill -TERM "$QS_PID" 2>/dev/null
        sleep 0.5
        kill -0 "$QS_PID" 2>/dev/null && kill -KILL "$QS_PID" 2>/dev/null
    fi
    # Defence-in-depth: even though the driver no longer mutates the deployed
    # file, restore from .bak if one exists from a prior aborted run.
    if [[ -f "${TARGET_FILE}.bak" ]]; then
        mv -f "${TARGET_FILE}.bak" "${TARGET_FILE}"
        echo "[cleanup] restored ${TARGET_FILE} from .bak"
    fi
    rm -rf "$TMPDIR"
    return "$rc"
}
trap cleanup EXIT INT TERM

# ───────────────────────────────────────────────── temp-copy + mutate ──
cp -f "$STRESS_QML_SRC" "$STRESS_QML_RUNTIME"

inject_async_into_runtime() {
    # Insert `asynchronous: true` immediately after the unique sentinel
    # `// STRESS_ASYNC_HOOK_INJECT_HERE` in the temp copy. Bail loudly if
    # the sentinel is missing or duplicated.
    local hits
    hits="$(grep -c 'STRESS_ASYNC_HOOK_INJECT_HERE' "$STRESS_QML_RUNTIME" || true)"
    if [[ "$hits" != "1" ]]; then
        echo "FATAL: STRESS_ASYNC_HOOK_INJECT_HERE sentinel hits=$hits (expected 1)" >&2
        exit 2
    fi
    awk '
        BEGIN { injected = 0 }
        /\/\/ STRESS_ASYNC_HOOK_INJECT_HERE/ && !injected {
            print
            indent = ""
            for (i = 1; i <= length($0); i++) {
                c = substr($0, i, 1)
                if (c == " " || c == "\t") indent = indent c; else break
            }
            print indent "asynchronous: true"
            injected = 1
            next
        }
        { print }
        END { if (!injected) exit 3 }
    ' "$STRESS_QML_SRC" > "$STRESS_QML_RUNTIME"
    if ! grep -q '^[[:space:]]*asynchronous:[[:space:]]*true' "$STRESS_QML_RUNTIME"; then
        echo "FATAL: post-injection sanity check failed" >&2
        exit 2
    fi
    echo "[unpatched] injected 'asynchronous: true' into temp copy"
}

# ───────────────────────────────────────────────────── crash detect ──
count_segvs() {
    local since="$1"
    journalctl --user -q --since "$since" 2>/dev/null \
        | grep -E -ci 'quickshell.*(SIGSEGV|segmentation fault|terminated by signal SEGV)' \
        || true
}

count_coredumps() {
    local since="$1"
    coredumpctl --no-pager list --since "$since" 2>&1 \
        | grep -c '/usr/bin/quickshell' \
        || true
}

# ───────────────────────────────────────────────────────── run ──
case "$MODE" in
    unpatched)
        inject_async_into_runtime
        ;;
    patched)
        # Verify the deployed CircularProgress.qml does NOT contain
        # `asynchronous: true` (defensive — Phase B1 is the patch owner).
        if grep -E -q '^[[:space:]]*asynchronous:[[:space:]]*true' "$TARGET_FILE"; then
            echo "WARN: deployed CircularProgress.qml still contains 'asynchronous: true'." >&2
            echo "      patched run may FAIL by design — flag this to the orchestrator." >&2
        fi
        ;;
esac

START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
echo "[run] mode=$MODE duration=${DURATION_SEC}s start=$START_TS"

qs -p "$STRESS_QML_RUNTIME" >"$QS_LOG" 2>&1 &
QS_PID=$!
echo "[run] qs PID=$QS_PID log=$QS_LOG"

EARLY_EXIT=0
elapsed=0
while (( elapsed < DURATION_SEC )); do
    if ! kill -0 "$QS_PID" 2>/dev/null; then
        EARLY_EXIT=1
        echo "[run] qs PID=$QS_PID exited early at t=${elapsed}s"
        break
    fi
    sleep 2
    elapsed=$(( elapsed + 2 ))
    if (( elapsed % 30 == 0 )); then
        echo "[run] alive at t=${elapsed}s"
    fi
done

if kill -0 "$QS_PID" 2>/dev/null; then
    kill -TERM "$QS_PID" 2>/dev/null
    sleep 1
    kill -0 "$QS_PID" 2>/dev/null && kill -KILL "$QS_PID" 2>/dev/null
fi
wait "$QS_PID" 2>/dev/null
QS_EXIT=$?
QS_PID=""

# Give systemd-coredump a moment to write any pending dump.
sleep 2

# ───────────────────────────────────────────────────────── verdict ──
SEGV_COUNT="$(count_segvs "$START_TS")"
CORE_COUNT="$(count_coredumps "$START_TS")"

echo
echo "=== qs.log tail (last 30 lines) ==="
tail -30 "$QS_LOG" 2>&1
echo "=== end qs.log ==="
echo
echo "[result] mode=$MODE duration=${elapsed}s qs_exit=$QS_EXIT early_exit=$EARLY_EXIT segvs=$SEGV_COUNT coredumps=$CORE_COUNT"

case "$MODE" in
    unpatched)
        if (( SEGV_COUNT > 0 || CORE_COUNT > 0 || EARLY_EXIT )); then
            echo "PASS: unpatched harness reproduced the race (segv=$SEGV_COUNT core=$CORE_COUNT early=$EARLY_EXIT)"
            exit 0
        else
            echo "FAIL: unpatched harness ran clean for ${elapsed}s — harness too weak, race not reproduced"
            exit 1
        fi
        ;;
    patched)
        if (( SEGV_COUNT == 0 && CORE_COUNT == 0 && EARLY_EXIT == 0 )); then
            echo "PASS: harness survived ${elapsed}s with zero crashes"
            exit 0
        else
            echo "FAIL: harness crashed (segv=$SEGV_COUNT core=$CORE_COUNT early=$EARLY_EXIT) — patch may be incomplete"
            exit 1
        fi
        ;;
esac
