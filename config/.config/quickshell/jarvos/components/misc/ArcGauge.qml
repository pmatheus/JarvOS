import QtQuick

// Circular arc gauge: a background track arc plus a foreground progress arc.
// Recreated locally after caelestia-shell 2.0.2 removed Caelestia.Internal/ArcGauge.
// API matches the original C++ type so call sites need no changes:
//   percentage  0..1 fraction filled
//   accentColor progress arc colour
//   trackColor  background arc colour
//   startAngle  arc start, in RADIANS (0 = 3 o'clock, increasing clockwise)
//   sweepAngle  arc extent, in RADIANS
// The centred value label is drawn by the caller as a sibling, not here.
Item {
    id: root

    property real percentage: 0
    property color accentColor: "white"
    property color trackColor: "transparent"
    property real startAngle: 0.75 * Math.PI
    property real sweepAngle: 1.5 * Math.PI
    property real lineWidth: Math.max(4, Math.min(width, height) * 0.09)

    onPercentageChanged: canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onStartAngleChanged: canvas.requestPaint()
    onSweepAngleChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(width, height) / 2 - root.lineWidth / 2;
            if (r <= 0)
                return;

            const p = Math.max(0, Math.min(1, root.percentage));
            const a0 = root.startAngle;

            ctx.lineCap = "round";
            ctx.lineWidth = root.lineWidth;

            // Track
            ctx.beginPath();
            ctx.strokeStyle = root.trackColor;
            ctx.arc(cx, cy, r, a0, a0 + root.sweepAngle, false);
            ctx.stroke();

            // Progress
            if (p > 0) {
                ctx.beginPath();
                ctx.strokeStyle = root.accentColor;
                ctx.arc(cx, cy, r, a0, a0 + root.sweepAngle * p, false);
                ctx.stroke();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
}
