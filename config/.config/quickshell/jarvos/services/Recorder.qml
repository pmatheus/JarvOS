pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.utils

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property real elapsed: 0
    property list<string> requestArgs: ["--status"]

    function request(args: list<string>): void {
        if (control.running)
            return;
        requestArgs = args;
        control.running = true;
    }

    function start(extraArgs = []): void { request(extraArgs); }
    function stop(): void { request(["--stop"]); }
    function togglePause(): void { request(["--pause"]); }

    FileView {
        path: `${Paths.state}/recorder.json`
        watchChanges: true
        onFileChanged: root.request(["--status"])
    }

    Process {
        id: control
        command: ["jarvos-desktop", "record", ...root.requestArgs]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                try {
                    const state = JSON.parse(text);
                    root.running = state.running;
                    root.paused = state.paused;
                    root.elapsed = state.elapsed;
                } catch (error) {
                    console.warn("Invalid recorder status: " + error);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    Toaster.toast(qsTr("Recording"), text.trim(), "error");
            }
        }
    }

    Timer {
        interval: 1000
        running: root.running
        repeat: true
        onTriggered: root.request(["--status"])
    }
}
