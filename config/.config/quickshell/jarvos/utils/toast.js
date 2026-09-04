.pragma library

// Toast queue logic for services/Toaster.qml, ported from caelestia's
// Toaster/Toast (plugin/src/Caelestia/toaster.cpp). The functions operate
// on plain duck-typed toast objects ({closed, locks, ...}) so the logic is
// unit-testable; the QML Toast type satisfies the same shape.

// Type ints, the single source of truth mirrored by the QML Toast enum.
var Info = 0;
var Success = 1;
var Warning = 2;
var Error = 3;

var defaultIcons = {
    0: "info",
    1: "check_circle_unread",
    2: "warning",
    3: "error"
};

var defaultTimeouts = {
    0: 5000,
    1: 5000,
    2: 7000,
    3: 10000
};

function create(title, message, icon, type, timeout) {
    return {
        title: title,
        message: message,
        icon: icon || defaultIcons[type],
        type: type,
        timeout: timeout > 0 ? timeout : defaultTimeouts[type],
        closed: false,
        locks: []
    };
}

// New toasts sit at the front of the list.
function push(queue, toast) {
    queue.unshift(toast);
}

function remove(queue, toast) {
    const i = queue.indexOf(toast);
    if (i !== -1)
        queue.splice(i, 1);
}

// Marks the toast closed and reports whether it is finished: a toast with
// outstanding locks stays in the queue until the last lock releases, which
// is what keeps an already-fading toast from being torn down mid-animation.
function close(toast) {
    if (!toast.closed)
        toast.closed = true;
    return toast.locks.length === 0;
}

function lock(toast, key) {
    if (!toast.locks.includes(key))
        toast.locks.push(key);
}

// Releases one lock and reports whether the toast finished as a result.
function unlock(toast, key) {
    const i = toast.locks.indexOf(key);
    if (i === -1)
        return false;
    toast.locks.splice(i, 1);
    return toast.locks.length === 0 && toast.closed;
}
