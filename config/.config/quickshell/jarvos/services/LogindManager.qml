import QtQuick

import Quickshell
import Quickshell.Io

import "../utils/session.js" as Session

// Logind session signals, ported from caelestia's C++ LogindManager of the
// same name. Quickshell has no logind module, so this watches the system
// bus with gdbus monitor and parses the lines in utils/session.js
// (unit-tested). Named LogindManager rather than Session because
// qs.modules.session is already imported as the Session namespace in
// drawer files. Consumers: IdleMonitors locks via hyprlock on
// aboutToSleep and honors logind's Lock/Unlock requests.
QtObject {
    id: root

    signal aboutToSleep()
    signal lockRequested()
    signal unlockRequested()

    property Timer restartTimer: Timer {
        interval: 1000
        onTriggered: monitor.running = true
    }

    property Process monitor: Process {
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: data => {
                const event = Session.parse(data);
                if (event === "sleep")
                    root.aboutToSleep();
                else if (event === "lock")
                    root.lockRequested();
                else if (event === "unlock")
                    root.unlockRequested();
            }
        }
        onExited: restartTimer.restart()
    }

    Component.onCompleted: monitor.running = true
}
