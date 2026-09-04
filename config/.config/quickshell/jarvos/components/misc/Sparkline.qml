import QtQuick

import "../../utils/sparkline.js" as Geometry

// Port of caelestia's C++ SparklineItem over our own CircularBuffer
// (utils/CircularBuffer.qml). Geometry lives in utils/sparkline.js and is
// unit-tested; this file is thin wiring. Line1 paints behind line2, values
// map unclamped against maxValue, and slideProgress animates the newest
// sample in from beyond the right edge.
Canvas {
    id: root

    property var line1
    property var line2
    property color line1Color: "transparent"
    property color line2Color: "transparent"
    property real line1FillAlpha: 0.15
    property real line2FillAlpha: 0.2
    property real maxValue: 1024
    property real slideProgress: 0
    property int historyLength: 30
    property real lineWidth: 2

    antialiasing: true

    onLine1Changed: requestPaint()
    onLine2Changed: requestPaint()
    onLine1ColorChanged: requestPaint()
    onLine2ColorChanged: requestPaint()
    onLine1FillAlphaChanged: requestPaint()
    onLine2FillAlphaChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onSlideProgressChanged: requestPaint()
    onHistoryLengthChanged: requestPaint()
    onLineWidthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: root.line1 ?? null

        function onValuesChanged(): void {
            root.requestPaint();
        }
    }

    Connections {
        target: root.line2 ?? null

        function onValuesChanged(): void {
            root.requestPaint();
        }
    }

    onPaint: region => {
        const ctx = root.getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const count1 = root.line1 ? root.line1.count : 0;
        const count2 = root.line2 ? root.line2.count : 0;
        if (!Geometry.shouldDraw(count1, count2))
            return;

        if (count1 >= 2)
            drawLine(ctx, root.line1.values, root.line1Color, root.line1FillAlpha);
        if (count2 >= 2)
            drawLine(ctx, root.line2.values, root.line2Color, root.line2FillAlpha);
    }

    function drawLine(ctx, values, color, fillAlpha): void {
        if (root.historyLength < 2 || values.length < 2)
            return;

        const pts = Geometry.linePoints(values, width, height, root.maxValue, root.historyLength, root.slideProgress);

        ctx.strokeStyle = color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(pts[0].x, pts[0].y);
        for (let i = 1; i < pts.length; i++)
            ctx.lineTo(pts[i].x, pts[i].y);
        ctx.stroke();

        const fill = Geometry.fillPoints(pts, height);
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, fillAlpha);
        ctx.beginPath();
        ctx.moveTo(fill[0].x, fill[0].y);
        for (let i = 1; i < fill.length; i++)
            ctx.lineTo(fill[i].x, fill[i].y);
        ctx.closePath();
        ctx.fill();
    }
}
