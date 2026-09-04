import QtQuick

import "../../utils/toast.js" as Queue

// One toast, ported from caelestia's C++ Toast. Created only by the Toaster
// singleton; the queue logic (lock sets, finish-on-last-unlock) lives in
// utils/toast.js and is unit-tested there. The expiry timer fires close()
// at the normalized timeout regardless of locks — a locked toast is marked
// closed but stays in the queue until its last lock releases, which is what
// keeps the exit animation alive.
QtObject {
    id: root

    // Mirrors toast.js's type constants, which are the source of truth.
    enum Type { Info, Success, Warning, Error }

    // Set once at creation by the Toaster; icon and timeout arrive already
    // normalized (see utils/toast.js).
    property string title
    property string message
    property string icon
    property int type
    property int timeout

    property bool closed: false

    signal finishedClose()

    property var locks: []
    property Timer _expiry: Timer {
        interval: root.timeout
        running: true
        onTriggered: root.close()
    }

    function close(): void {
        if (Queue.close(root))
            finishedClose();
    }

    function lock(sender): void {
        Queue.lock(root, sender);
    }

    function unlock(sender): void {
        if (Queue.unlock(root, sender))
            close();
    }
}
