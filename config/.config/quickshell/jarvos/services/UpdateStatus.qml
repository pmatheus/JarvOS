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

    property var reboot: ({
        "required": false,
        "reasons": [],
        "scheduled": false,
        "scheduled_time": "",
        "scheduled_mode": "",
        "scheduled_message": "",
        "scheduled_seconds_left": 0
    })

    readonly property bool rebootRequired: (root.reboot && root.reboot.required) ? true : false
    readonly property var rebootReasons: (root.reboot && root.reboot.reasons) ? root.reboot.reasons : []
    readonly property bool rebootScheduled: (root.reboot && root.reboot.scheduled) ? true : false
    readonly property string scheduledRebootTime: (root.reboot && root.reboot.scheduled_time) ? root.reboot.scheduled_time : ""
    readonly property int scheduledRebootSecondsLeft: (root.reboot && root.reboot.scheduled_seconds_left) ? root.reboot.scheduled_seconds_left : 0

    property bool updating: false
    property string updatePhase: ""
    property string currentPhaseId: ""
    property string currentLogLine: ""
    property var logLines: []
    property bool updateFinished: false
    property bool updateSuccess: false

    function startUpdate(mode: string): void {
        if (updating || updateProc.running)
            return;

        root.updating = true;
        root.updateFinished = false;
        root.updateSuccess = false;
        root.updatePhase = qsTr("Iniciando atualização...");
        root.currentPhaseId = "init";
        root.currentLogLine = "";
        root.logLines = [];

        updateProc.command = [`${Quickshell.shellDir}/scripts/run-update.py`, mode || "--system"];
        updateProc.running = true;
    }

    function dismissUpdate(): void {
        root.updating = false;
        root.updateFinished = false;
        root.refresh();
    }

    function pushLog(line: string): void {
        root.currentLogLine = line;
        const current = root.logLines ? root.logLines.slice() : [];
        current.push(line);
        if (current.length > 150)
            current.shift();
        root.logLines = current;
    }

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

    function rebootNow(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function scheduleReboot(mins: int, timeStr: string): void {
        const arg = mins > 0 ? ("+" + mins) : timeStr;
        Quickshell.execDetached(["shutdown", "-r", arg, "Reboot scheduled via JarvOS"]);
        scheduleRefreshTimer.start();
    }

    function cancelScheduledReboot(): void {
        Quickshell.execDetached(["shutdown", "-c"]);
        scheduleRefreshTimer.start();
    }

    // Hourly automatic update check
    Timer {
        id: hourlyTimer
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Initial check on shell startup
    Timer {
        id: startupTimer
        interval: 8000
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    // Delayed refresh after schedule/cancel
    Timer {
        id: scheduleRefreshTimer
        interval: 1200
        running: false
        repeat: false
        onTriggered: root.refresh()
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
                    if (data.reboot)
                        root.reboot = data.reboot;
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

    Process {
        id: updateProc

        running: false
        command: [`${Quickshell.shellDir}/scripts/run-update.py`, "--system"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const trimmed = data.trim();
                    if (trimmed.length === 0)
                        return;
                    const evt = JSON.parse(trimmed);
                    if (evt.type === "phase") {
                        root.updatePhase = evt.text;
                        root.currentPhaseId = evt.phase;
                    } else if (evt.type === "log") {
                        root.pushLog(evt.line);
                    } else if (evt.type === "reboot") {
                        root.reboot = evt;
                    } else if (evt.type === "done") {
                        root.updateSuccess = evt.success ?? true;
                        root.updating = false;
                        root.updateFinished = true;
                        root.refresh();
                    }
                } catch (e) {
                    if (data.trim().length > 0)
                        root.pushLog(data.trim());
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    root.pushLog(data.trim());
            }
        }

        onExited: exitCode => {
            if (root.updating) {
                root.updating = false;
                root.updateFinished = true;
                root.updateSuccess = exitCode === 0;
                root.refresh();
            }
        }
    }
}
