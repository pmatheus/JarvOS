pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool running: false
    property string generatedAt: ""
    property string error: ""
    property int total: 0
    property var groups: []
    property real lastRefreshStarted: 0

    function refresh(): void {
        if (proc.running)
            return;

        root.error = "";
        root.running = true;
        root.lastRefreshStarted = Date.now();
        proc.running = true;
    }

    function refreshIfStale(maxAgeMs: int): void {
        if (root.running)
            return;
        if (root.generatedAt === "" || Date.now() - root.lastRefreshStarted > maxAgeMs)
            root.refresh();
    }

    Process {
        id: proc

        running: false
        command: [`${Quickshell.shellDir}/scripts/update-status.py`]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.generatedAt = data.generated_at ?? "";
                    root.groups = data.groups ?? [];
                    root.total = data.total ?? 0;
                    root.error = "";
                } catch (err) {
                    root.error = String(err);
                    root.groups = [];
                    root.total = 0;
                }
                root.running = false;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.error = text.trim();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.error === "")
                root.error = qsTr("Update check exited with code %1").arg(exitCode);
            root.running = false;
        }
    }
}
