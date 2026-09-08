.pragma library

// cava raw-ascii stdout parsing for services/Audio.qml's visualiser port.
// cava emits one frame per line, values separated by the configured
// delimiter, each 0..ascii_max_range. Values normalise to 0..1, matching
// the shape the C++ CavaProvider produced. A malformed, partial or
// negative frame is rejected so a glitch never corrupts the graph.

function parseFrame(line, maxRange, expectedBars) {
    if (!line)
        return null;
    const parts = line.trim().split(/\s+/);
    if (parts.length === 0 || (parts.length === 1 && parts[0] === ""))
        return null;
    if (expectedBars !== undefined && parts.length !== expectedBars)
        return null;

    const values = [];
    for (const part of parts) {
        const value = Number(part);
        if (!isFinite(value) || value < 0 || value > maxRange)
            return null;
        values.push(value / maxRange);
    }
    return values;
}
