//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_RHI_BACKEND=vulkan
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Phase B2 stress harness — torture-tests the QQuickShapeCurveRunnable race.
//
// THE BUG: a `Shape { asynchronous: true; preferredRendererType:
// Shape.CurveRenderer; ShapePath { PathAngleArc {...} } }` queues a
// QQuickShapeCurveRunnable to QThreadPool. If the parent Shape is destroyed
// before the worker emits done(this), QObjectPrivate::ConnectionData::
// cleanOrphanedConnections dereferences freed memory and SIGSEGVs.
//
// The deployed CircularProgress.qml uses exactly this Shape pattern. Its
// pre-patch form had `asynchronous: true`; the patch deleted that line.
// We can't import the deployed control from outside its `shell.qml`-rooted
// namespace (QuickShell `qs.X` imports only resolve when the entry file is
// shell.qml), so this harness inlines the same Shape geometry. The
// `unpatched` driver edits a TEMP COPY of this file (not the repo source)
// to re-add `asynchronous: true` to ShapeCell, which faithfully reproduces
// the race the deployed control would have hit pre-patch.
//
// MARKER LINE — the driver inserts `asynchronous: true` immediately after
// the unique sentinel below ShapeCell. Do not duplicate the sentinel.
//
// Tunables — 128 instances on an 8ms timer is well above the architect's
// 64@16ms draft. Initial 60s runs at the lower setting could not reproduce
// the race even with `asynchronous: true` injected.

import Quickshell
import QtQuick
import QtQuick.Shapes

ShellRoot {
    PanelWindow {
        id: panel
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"

        // Click-through so we don't steal input from the live shell.
        mask: Region {
            width: 0
            height: 0
        }

        property int churnCount: 256
        property int generation: 0

        Repeater {
            id: rep
            model: panel.churnCount

            ShapeCell {
                width: 80
                height: 80
                x: Math.random() * Math.max(1, panel.width - 80)
                y: Math.random() * Math.max(1, panel.height - 80)
                value: Math.random()
                fgColour: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
                bgColour: Qt.rgba(Math.random(), Math.random(), Math.random(), 0.4)
            }
        }

        // Multi-rate churn — different timer rates create overlapping
        // destroy/finish windows. A worker finishing at t=N may collide with
        // a destroy from a different timer at t=N+1.
        Timer {
            interval: 4
            running: true
            repeat: true
            onTriggered: {
                rep.model = 0;
                rep.model = panel.churnCount;
                panel.generation += 1;
                if (panel.generation % 50 === 0) {
                    Qt.callLater(gc);
                }
            }
        }

        // Property thrash — change a binding the inlined cells depend on
        // every 7ms. This forces re-render requests that interleave with
        // the destroy/recreate cycle.
        property real globalThrash: 0
        Timer {
            interval: 7
            running: true
            repeat: true
            onTriggered: panel.globalThrash = Math.random()
        }

        // Loader cluster — 16 Loaders each with asynchronous: true,
        // toggling active at staggered intervals. This mirrors the panel
        // show/hide pattern (Drawers / Lock) that was implicated in the
        // production crashes.
        Repeater {
            model: 16
            Loader {
                id: aLoader
                asynchronous: true
                active: false
                x: 50 + 100 * (index % 8)
                y: panel.height - 200 - 100 * Math.floor(index / 8)
                sourceComponent: ShapeCell {
                    width: 60 + (panel.globalThrash * 20)
                    height: 60 + (panel.globalThrash * 20)
                    value: panel.globalThrash
                }
                Timer {
                    interval: 5 + index
                    running: true
                    repeat: true
                    onTriggered: aLoader.active = !aLoader.active
                }
            }
        }

        // Self-terminate after 5 minutes.
        Timer {
            interval: 5 * 60 * 1000
            running: true
            repeat: false
            onTriggered: {
                console.log("stress-shape-thrash: clean exit after 5min, generation=" + panel.generation);
                Qt.quit();
            }
        }

        // Heartbeat so we can see it's actually running.
        Timer {
            interval: 5000
            running: true
            repeat: true
            onTriggered: console.log("stress-shape-thrash: alive, generation=" + panel.generation)
        }

        component ShapeCell: Shape {
            id: cell

            property real value: 0.5
            property color fgColour: "white"
            property color bgColour: "gray"

            readonly property real size: Math.min(width, height)
            readonly property real strokeWidth: 6
            readonly property real arcRadius: (size - strokeWidth) / 2
            readonly property real vValue: cell.value || 1 / 360

            preferredRendererType: Shape.CurveRenderer
            // STRESS_ASYNC_HOOK_INJECT_HERE

            ShapePath {
                fillColor: "transparent"
                strokeColor: cell.bgColour
                strokeWidth: cell.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    startAngle: -90 + 360 * cell.vValue + 4
                    sweepAngle: Math.max(-4, 360 * (1 - cell.vValue) - 8)
                    radiusX: cell.arcRadius
                    radiusY: cell.arcRadius
                    centerX: cell.size / 2
                    centerY: cell.size / 2
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: cell.fgColour
                strokeWidth: cell.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    startAngle: -90
                    sweepAngle: 360 * cell.vValue
                    radiusX: cell.arcRadius
                    radiusY: cell.arcRadius
                    centerX: cell.size / 2
                    centerY: cell.size / 2
                }
            }
        }
    }
}
