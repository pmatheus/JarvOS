.pragma library

// Indeterminate circular-indicator maths, ported from caelestia's
// CircularIndicatorManager (plugin/src/Caelestia/Components/
// circularindicatormanager.cpp). The QML manager drives `progress` 0..1
// and reads the fractions it produces; the consumer's CircularProgress
// paints from startFraction*360 to endFraction*360 at `rotation`.
//
// Two modes. Advance: a constant 1520deg rotation with four expand/collapse
// cycles of 250deg each (5400ms). Retreat: a constant 1080deg rotation with
// four eased 90deg spins, the active arc growing 0..3000ms and shrinking
// 3000..6000ms between 10% and 87% (6000ms).

// Material standard easing: cubic-bezier(0.4, 0, 0.2, 1), "fast out slow in".
function ease(t) {
    const x = Math.min(1, Math.max(0, t));
    if (x === 0)
        return 0;
    if (x === 1)
        return 1;

    // Solve for the parameter that gives progress x along the curve's x
    // axis, then return the y of the curve at that parameter. Newton first,
    // bisection as the fallback.
    const p1x = 0.4, p1y = 0.0, p2x = 0.2, p2y = 1.0;
    const cx = 3 * p1x;
    const bx = 3 * (p2x - p1x) - cx;
    const ax = 1 - cx - bx;
    const cy = 3 * p1y;
    const by = 3 * (p2y - p1y) - cy;
    const ay = 1 - cy - by;

    const sampleX = t => ((ax * t + bx) * t + cx) * t;
    const sampleY = t => ((ay * t + by) * t + cy) * t;
    const sampleDX = t => (3 * ax * t + 2 * bx) * t + cx;

    let guess = x;
    for (let i = 0; i < 8; ++i) {
        const currentX = sampleX(guess) - x;
        if (Math.abs(currentX) < 1e-7)
            return sampleY(guess);
        const d = sampleDX(guess);
        if (Math.abs(d) < 1e-7)
            break;
        guess -= currentX / d;
    }

    // Bisection fallback.
    let lo = 0, hi = 1;
    guess = x;
    for (let i = 0; i < 24; ++i) {
        const currentX = sampleX(guess);
        if (Math.abs(currentX - x) < 1e-7)
            break;
        if (currentX < x)
            lo = guess;
        else
            hi = guess;
        guess = (lo + hi) / 2;
    }
    return sampleY(guess);
}

// Type ints, mirrored by the QML manager's enum.
var Advance = 0;
var Retreat = 1;

const ADVANCE = {
    cycles: 4,
    totalDuration: 5400,
    durationToExpand: 667,
    durationToCollapse: 667,
    durationToCompleteEnd: 333,
    tailDegreesOffset: -20,
    extraDegreesPerCycle: 250,
    constantRotationDegrees: 1520,
    delayToExpand: [0, 1350, 2700, 4050],
    delayToCollapse: [667, 2017, 3367, 4717]
};

const RETREAT = {
    totalDuration: 6000,
    durationSpin: 500,
    durationGrowActive: 3000,
    durationShrinkActive: 3000,
    delaySpins: [0, 1500, 3000, 4500],
    delayGrowActive: 0,
    delayShrinkActive: 3000,
    durationToCompleteEnd: 500,
    constantRotationDegrees: 1080,
    spinRotationDegrees: 90,
    endFractionRange: [0.10, 0.87]
};

function duration(type) {
    return type === Advance ? ADVANCE.totalDuration : RETREAT.totalDuration;
}

function completeEndDuration(type) {
    return type === Advance ? ADVANCE.durationToCompleteEnd : RETREAT.durationToCompleteEnd;
}

function inRange(playtime, start, span) {
    const fraction = (playtime - start) / span;
    return Math.min(1, Math.max(0, fraction));
}

function advance(progress, completeEndProgress) {
    const playtime = progress * ADVANCE.totalDuration;
    let start = ADVANCE.constantRotationDegrees * progress + ADVANCE.tailDegreesOffset;
    let end = ADVANCE.constantRotationDegrees * progress;

    for (let cycle = 0; cycle < ADVANCE.cycles; ++cycle) {
        end += ease(inRange(playtime, ADVANCE.delayToExpand[cycle], ADVANCE.durationToExpand)) * ADVANCE.extraDegreesPerCycle;
        start += ease(inRange(playtime, ADVANCE.delayToCollapse[cycle], ADVANCE.durationToCollapse)) * ADVANCE.extraDegreesPerCycle;
    }

    // Close the gap between head and tail for the complete-end animation.
    start += (end - start) * completeEndProgress;

    return {
        startFraction: start / 360,
        endFraction: end / 360,
        rotation: 0
    };
}

function retreat(progress, completeEndProgress) {
    const playtime = progress * RETREAT.totalDuration;

    // Constant rotation plus the eased extra spins.
    let rotation = RETREAT.constantRotationDegrees * progress;
    for (const spinDelay of RETREAT.delaySpins)
        rotation += ease(inRange(playtime, spinDelay, RETREAT.durationSpin)) * RETREAT.spinRotationDegrees;

    // The active arc grows over the first half and shrinks over the second.
    let fraction = ease(inRange(playtime, RETREAT.delayGrowActive, RETREAT.durationGrowActive));
    fraction -= ease(inRange(playtime, RETREAT.delayShrinkActive, RETREAT.durationShrinkActive));
    const range = RETREAT.endFractionRange;
    let end = range[0] + (range[1] - range[0]) * fraction;

    if (completeEndProgress > 0)
        end *= 1 - completeEndProgress;

    return {
        startFraction: 0,
        endFraction: end,
        rotation: rotation
    };
}

// One update: returns the full state for a progress position. type 0 =
// Advance, 1 = Retreat.
function update(progress, completeEndProgress, type) {
    return type === Advance ? advance(progress, completeEndProgress) : retreat(progress, completeEndProgress);
}
