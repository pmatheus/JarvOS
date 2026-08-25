#!/usr/bin/env bash
# Run the QML unit suites.
#
# MUST use the Qt 6 runner explicitly: /usr/bin/qmltestrunner is Qt 5, from
# qt5-declarative, and fails silently with exit 1 and no output at all
# against Qt 6 modules. That failure looks exactly like "no tests found".
#
# Only .js libraries are unit-testable. QML components importing qs.* are not
# loadable here — qs.* is a Quickshell convention plain Qt cannot resolve.

set -uo pipefail

RUNNER=/usr/lib/qt6/bin/qmltestrunner
HERE="$(cd "$(dirname "$0")" && pwd)"
SHELL_ROOT="$(cd "$HERE/../../config/.config/quickshell/jarvos" && pwd)"

if [[ ! -x "$RUNNER" ]]; then
    echo "qml: $RUNNER not found — install qt6-declarative" >&2
    exit 1
fi

QT_QPA_PLATFORM=offscreen "$RUNNER" -input "$HERE" -import "$SHELL_ROOT"
