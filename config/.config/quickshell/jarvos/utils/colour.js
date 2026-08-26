.pragma library

// Reproduces what Caelestia's image analyser computed, kept out of QML so the
// arithmetic is pinned by tests. The shell was tuned against these numbers, so
// the point of the file is to not move them.

// Rec. 601 weights over squared channels, square-rooted — the same expression
// as Colours.qml's getLuminance. The linear averages usually reached for read
// a mid green roughly a quarter darker, which would retint every layered
// surface at once.
function luminance(r, g, b) {
    return Math.sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b);
}

// The plugin averaged luminance over every opaque pixel. ColorQuantizer
// hands back a median-cut palette instead, and median cut splits each box at
// the median, so every bucket holds the same number of pixels — an unweighted
// mean over the palette is that same average, sampled.
//
// It reads very slightly low: luminance is a norm, so by Jensen a bucket's
// mean colour is never brighter than the mean of its pixels. Depth is what
// closes the gap.
function meanLuminance(colours) {
    if (!colours || colours.length === 0)
        return 0;

    let total = 0;
    for (const c of colours)
        total += luminance(c.r, c.g, c.b);
    return total / colours.length;
}

// The plugin's dominant colour was the mode of a histogram binned on the top
// five bits of each channel. Same binning here, over the palette rather than
// over every pixel: because the buckets are equal-population, a flat region of
// the image turns into many palette entries that all round to one bin, so the
// mode survives the change of input.
function dominant(colours) {
    if (!colours || colours.length === 0)
        return null;

    const bins = {};
    for (const c of colours) {
        const key = [c.r, c.g, c.b].map(v => Math.round(v * 255) & 0xf8).join(",");
        const bin = bins[key] ?? (bins[key] = {
            count: 0,
            colour: c
        });
        bin.count++;
    }

    let best = null;
    let bestCount = 0;
    for (const key in bins)
        if (bins[key].count > bestCount) {
            bestCount = bins[key].count;
            best = bins[key].colour;
        }

    return best;
}
