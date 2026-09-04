.pragma library

// Sparkline geometry, ported from caelestia-shell's SparklineItem
// (plugin/src/Caelestia/Components/sparklineitem.cpp) so that
// components/misc/Sparkline.qml can paint it on a Canvas.
//
// The oldest value is index 0; the newest sits at the right edge when
// slideProgress reaches 1 and one step beyond it when it is 0, so the
// Performance card can animate each sample sliding in from the right.
// Values are mapped unclamped: anything above maxValue overflows the top,
// exactly like the original.

function shouldDraw(count1, count2) {
    return count1 >= 2 || count2 >= 2;
}

function stepX(width, historyLength) {
    return width / (historyLength - 1);
}

function startX(width, count, historyLength, slideProgress) {
    const step = stepX(width, historyLength);
    return width - (count - 1) * step - step * slideProgress + step;
}

function linePoints(values, width, height, maxValue, historyLength, slideProgress) {
    const step = stepX(width, historyLength);
    const start = startX(width, values.length, historyLength, slideProgress);
    const pts = [];
    for (let i = 0; i < values.length; i++) {
        pts.push({
            x: start + i * step,
            y: height - (values[i] / maxValue) * height
        });
    }
    return pts;
}

function fillPoints(linePts, height) {
    if (linePts.length < 2)
        return [];
    const last = linePts[linePts.length - 1];
    const fill = linePts.slice();
    fill.push({
        x: last.x,
        y: height
    }, {
        x: linePts[0].x,
        y: height
    });
    return fill;
}
