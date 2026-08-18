pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Backend for the first-run "JarvOS Setup" panel.
//
// Owns three things: the module catalogue (read from jarvos-module-install
// --list), the live progress of a detached install (a flat key=value state
// file the backend rewrites atomically), and the first-run markers.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/jarvos`
    readonly property string statePath: `${stateDir}/setup-state`
    readonly property string donePath: `${stateDir}/first-run-done`
    readonly property string pendingPath: "/var/lib/jarvos/first-run-pending"

    // Single place that knows where the backend lives, shared by every call so
    // a packaged install and a git checkout behave identically.
    readonly property string finder: 'for c in "${JARVOS_MODULE_INSTALL:-}" /usr/local/bin/jarvos-module-install /usr/bin/jarvos-module-install "$HOME/JarvOS/scripts/jarvos-module-install"; do [ -n "$c" ] && [ -x "$c" ] && exec "$c" "$@"; done; echo "jarvos-module-install not found in PATH or /usr/local/bin" >&2; exit 127'

    property list<var> modules: []
    property bool loading
    property string listError

    property string overall: "idle"
    property string current
    property string message
    property string askpass
    // id -> { status, done, total, message, log, failed }
    property var progress: ({})

    // JARVOS_PROFILE is what the user asked for in the installer wizard, not
    // what stage 1 installed (which is the same 99 packages either way). This
    // file is the only place that answer survives, so the panel honours it.
    property string installProfile
    readonly property bool toolchainReady: _toolchainReady
    property bool _toolchainReady: true

    property bool markerPending
    property bool markerDone
    readonly property bool firstRun: markerPending && !markerDone
    readonly property bool busy: overall === "running" || overall === "needs-password"
    readonly property bool needsPassword: overall === "needs-password" && askpass !== ""

    signal moduleFinished(string id, bool ok, string name)

    function progressFor(id: string): var {
        return progress[id] ?? ({
                status: "idle",
                done: 0,
                total: 0,
                message: "",
                log: "",
                failed: ""
            });
    }

    function moduleName(id: string): string {
        return modules.find(m => m.id === id)?.name ?? id;
    }

    function refresh(): void {
        pendingFile.reload();
        doneFile.reload();
        if (listProc.running)
            return;
        root.loading = true;
        listProc.running = true;
    }

    function install(ids: var): void {
        if (!ids || ids.length === 0)
            return;
        // setsid detaches the run from the shell: reloading or restarting
        // quickshell must never abort an install in flight.
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", root.finder, "jarvos-module-install", ...ids]);
        root.overall = "running";
        stateFile.reload();
    }

    function submitPassword(password: string): void {
        if (root.askpass === "")
            return;
        passProc.fifo = root.askpass;
        passProc.running = true;
        passProc.write(password + "\n");
        passProc.stdinEnabled = false;
    }

    function markDone(): void {
        Quickshell.execDetached(["sh", "-c", `mkdir -p '${root.stateDir}' && date -Iseconds > '${root.donePath}'`]);
        root.markerDone = true;
    }

    function openLog(path: string): void {
        if (path !== "")
            Quickshell.execDetached(["xdg-open", path]);
    }

    function _parseState(text: string): void {
        const next = {};
        let overall = "idle";
        let current = "";
        let message = "";
        let askpass = "";

        for (const line of text.split("\n")) {
            const sep = line.indexOf("=");
            if (sep < 0)
                continue;
            const key = line.slice(0, sep);
            const value = line.slice(sep + 1);

            if (key === "overall")
                overall = value;
            else if (key === "current")
                current = value;
            else if (key === "message")
                message = value;
            else if (key === "askpass")
                askpass = value;
            else if (key.startsWith("module.")) {
                const parts = key.split(".");
                const id = parts[1];
                const field = parts.slice(2).join(".");
                if (!next[id])
                    next[id] = {
                        status: "idle",
                        done: 0,
                        total: 0,
                        message: "",
                        log: "",
                        failed: ""
                    };
                if (field === "done" || field === "total")
                    next[id][field] = parseInt(value, 10) || 0;
                else
                    next[id][field] = value;
            }
        }

        for (const id in next) {
            const was = root.progress[id]?.status ?? "";
            const now = next[id].status;
            if (was !== now && (now === "done" || now === "failed"))
                root.moduleFinished(id, now === "done", root.moduleName(id));
        }

        root.progress = next;
        root.overall = overall;
        root.current = current;
        root.message = message;
        root.askpass = askpass;

        if (overall === "done" || overall === "failed")
            root.refresh();
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc

        running: false
        command: ["sh", "-c", root.finder, "jarvos-module-install", "--list"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.modules = d.modules ?? [];
                    root._toolchainReady = d.toolchain_ready !== false;
                    root.listError = "";
                } catch (err) {
                    root.modules = [];
                    root.listError = qsTr("Could not read the module catalogue: %1").arg(String(err));
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.listError = text.trim();
            }
        }

        onExited: root.loading = false
    }

    // Hands the sudo password to the backend over its private FIFO. The value
    // only ever travels on this pipe: never in argv, never in a file.
    Process {
        id: passProc

        property string fifo

        running: false
        stdinEnabled: true
        command: ["sh", "-c", 'cat > "$1"', "sh", fifo]
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root._parseState(text())

        // No state file means no run has happened here: say so rather than
        // keeping the last result on screen forever.
        onLoadFailed: {
            root.progress = ({});
            root.overall = "idle";
            root.current = "";
            root.message = "";
            root.askpass = "";
        }
    }

    // inotify does not survive the backend's atomic rewrite reliably, so poll
    // while an install is in flight. Idle costs nothing.
    Timer {
        running: root.busy
        interval: 500
        repeat: true
        onTriggered: stateFile.reload()
    }

    FileView {
        path: "/etc/jarvos-release"
        printErrors: false
        preload: true

        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("JARVOS_PROFILE="));
            root.installProfile = line ? line.split("=")[1].replace(/["']/g, "").trim() : "";
        }
        onLoadFailed: root.installProfile = ""
    }

    FileView {
        id: pendingFile

        path: root.pendingPath
        printErrors: false

        onLoaded: root.markerPending = true
        onLoadFailed: root.markerPending = false
    }

    FileView {
        id: doneFile

        path: root.donePath
        printErrors: false

        onLoaded: root.markerDone = true
        onLoadFailed: root.markerDone = false
    }
}
