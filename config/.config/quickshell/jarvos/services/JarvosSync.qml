pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Backend for the two profile doors in the Setup panel.
//
// jarvos-sync (T7) writes one JSON object, rewritten atomically on every
// update, to $JARVOS_SYNC_PROGRESS or $XDG_RUNTIME_DIR/jarvos-sync/progress.json.
// It is created before any work starts and always ends on "done" or "failed",
// so the panel never has to guess whether the tool died.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string progressPath: Quickshell.env("JARVOS_SYNC_PROGRESS") || `${runtimeDir}/jarvos-sync/progress.json`

    readonly property string finder: 'for c in "${JARVOS_SYNC:-}" /usr/local/bin/jarvos-sync /usr/bin/jarvos-sync "$HOME/JarvOS/scripts/jarvos-sync"; do [ -n "$c" ] && [ -x "$c" ] && exec "$c" "$@"; done; echo "jarvos-sync not found in PATH or /usr/local/bin" >&2; exit 127'

    property string action
    property string status: "idle"
    property string phase
    property int phaseIndex
    property int phaseTotal: 4
    property int step
    property int stepTotal
    property string message
    property string log
    property string secretsManifest

    property bool dryRun
    property string lastError

    // The progress file outlives the run that wrote it, and other tooling uses
    // the same path. Only report a run this session started — or one still in
    // flight, which we adopt so a shell reload does not lose a live restore.
    property bool owned

    // gh repo list, empty when gh is missing or not authenticated.
    property list<var> repos: []
    property bool reposLoading
    property string reposError

    readonly property bool running: owned && status === "running"
    readonly property bool finished: owned && (status === "done" || status === "failed")
    // Coarse bar from the phase, fine bar from the step. step_total is 0 when
    // the tool cannot know it yet, which means indeterminate, not zero.
    readonly property bool indeterminate: running && stepTotal <= 0
    readonly property real fraction: {
        if (phaseTotal <= 0)
            return 0;
        const base = Math.max(0, phaseIndex - 1) / phaseTotal;
        if (stepTotal <= 0)
            return base;
        return base + Math.min(1, step / stepTotal) / phaseTotal;
    }

    signal syncFinished(string action, bool ok)

    function restore(url: string, force: bool, preview: bool): void {
        if (root.running || url.trim() === "")
            return;
        const args = ["restore", url.trim(), "--progress"];
        if (force)
            args.push("--force");
        if (preview)
            args.push("--dry-run");
        root.dryRun = preview;
        root.lastError = "";
        root._launch(args);
    }

    function createProfile(name: string): void {
        if (root.running)
            return;
        const args = ["init"];
        if (name.trim() !== "")
            args.push("--repo", name.trim());
        args.push("--progress");
        root.dryRun = false;
        root.lastError = "";
        root._launch(args);
    }

    function loadRepos(): void {
        if (repoProc.running)
            return;
        root.reposLoading = true;
        root.reposError = "";
        repoProc.running = true;
    }

    function openLog(): void {
        if (root.log !== "")
            Quickshell.execDetached(["xdg-open", root.log]);
    }

    function _launch(args: var): void {
        // Detached for the same reason module installs are: a shell reload must
        // not abort a restore halfway through someone's machine.
        Quickshell.execDetached(["setsid", "-f", "sh", "-c", root.finder, "jarvos-sync", ...args]);
        root.owned = true;
        root.status = "running";
        root.action = args[0];
        root.phaseIndex = 0;
        root.step = 0;
        root.stepTotal = 0;
        root.message = qsTr("Starting");
        progressFile.reload();
    }

    function _parse(text: string): void {
        let d;
        try {
            d = JSON.parse(text);
        } catch (err) {
            return; // a half-written file; the next atomic rewrite will land
        }

        const was = root.status;
        // Adopt a run that is still going: it is either ours across a reload,
        // or a jarvos-sync the user started from a terminal, and either way the
        // panel should show it rather than sit blank while the machine changes.
        if (d.status === "running")
            root.owned = true;
        else if (!root.owned)
            return;

        root.action = d.action ?? "";
        root.phase = d.phase ?? "";
        root.phaseIndex = d.phase_index ?? 0;
        root.phaseTotal = d.phase_total ?? 4;
        root.step = d.step ?? 0;
        root.stepTotal = d.step_total ?? 0;
        root.message = d.message ?? "";
        root.log = d.log ?? "";
        root.secretsManifest = d.secrets_manifest ?? "";
        root.status = d.status ?? "idle";

        if (root.status === "failed")
            root.lastError = root.message;

        if (was === "running" && root.finished)
            root.syncFinished(root.action, root.status === "done");
    }

    Process {
        id: repoProc

        running: false
        command: ["sh", "-c", "gh auth status >/dev/null 2>&1 || exit 3; gh repo list --limit 50 --json name,url,isPrivate,description"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.repos = JSON.parse(text) ?? [];
                } catch (err) {
                    root.repos = [];
                }
            }
        }

        onExited: code => {
            root.reposLoading = false;
            if (code === 3)
                root.reposError = qsTr("GitHub CLI is not signed in — run `gh auth login`, or paste the URL.");
            else if (code === 127)
                root.reposError = qsTr("GitHub CLI is not installed — paste the repository URL instead.");
            else if (code !== 0)
                root.reposError = qsTr("Could not list your repositories.");
        }
    }

    FileView {
        id: progressFile

        path: root.progressPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root._parse(text())
        onLoadFailed: {
            if (!root.running)
                root.status = "idle";
        }
    }

    Timer {
        running: root.running
        interval: 400
        repeat: true
        onTriggered: progressFile.reload()
    }
}
