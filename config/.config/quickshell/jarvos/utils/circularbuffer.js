.pragma library

// Ring buffer implementation for sparklines and time-series metrics.
//
// Maintains up to `capacity` values in FIFO order.
// `maximum` is computed over the retained window only, returning 0 when empty.
// `at(0)` is the oldest retained entry; `at(count - 1)` is the newest.

function create(capacity) {
    return {
        capacity: Math.max(1, parseInt(capacity, 10) || 10),
        items: []
    };
}

function setCapacity(buf, capacity) {
    if (!buf)
        return;
    buf.capacity = Math.max(1, parseInt(capacity, 10) || 1);
    if (buf.items.length > buf.capacity) {
        buf.items = buf.items.slice(buf.items.length - buf.capacity);
    }
}

function push(buf, value) {
    if (!buf)
        return;
    const num = Number(value);
    const val = isFinite(num) ? num : 0;

    buf.items.push(val);
    if (buf.items.length > buf.capacity) {
        buf.items.shift();
    }
}

function at(buf, index) {
    if (!buf || index < 0 || index >= buf.items.length)
        return 0;
    return buf.items[index];
}

function count(buf) {
    if (!buf)
        return 0;
    return buf.items.length;
}

function values(buf) {
    if (!buf)
        return [];
    return buf.items.slice();
}

function maximum(buf) {
    if (!buf || buf.items.length === 0)
        return 0;
    let max = buf.items[0];
    for (let i = 1; i < buf.items.length; i++) {
        if (buf.items[i] > max)
            max = buf.items[i];
    }
    return max;
}

function clear(buf) {
    if (!buf)
        return;
    buf.items = [];
}
