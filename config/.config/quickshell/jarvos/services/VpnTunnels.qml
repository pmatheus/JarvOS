pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The case-VPN connection engine behind the bar's VPN menu.
//
// This is a singleton on purpose: the bar popouts are Loaders that unload
// when the menu closes, and a Process is killed with the item that owns it.
// The first version ran openconnect inside the popout, and the tunnel died
// the moment the mouse left the menu. Here the connection outlives any menu.
//
// It runs the client rather than a terminal, and that is a security
// property: a terminal echoes what is typed, so a 2FA code — and, on a
// retry, the password — end up on screen and in scrollback. A Process has
// no tty, so nothing is echoed, and the menu's field masks what is typed.
//
// Secrets never reach a command line. The password goes keyring → stdin,
// and openconnect is given --passwd-on-stdin; argv holds only server,
// protocol and username.
Singleton {
    id: root

    property bool connected: false
    // Every live tunnel: [{iface, ip, profile}]. Several can be up at once —
    // one per case — which is why nothing assumes a single address.
    property var tunnels: []
    property var profiles: []
    readonly property var connectedProfiles: tunnels.map(t => t.profile).filter(p => p)

    // Sessions are keyed by profile name and run independently:
    // phase: "" | "auth" (connecting) ; stage: portal/prompt/browser/tunnel/error.
    property var sessions: ({})
    property var sessionViews: []
    property var connectingSessionViews: []
    property var errorSessionViews: []

    property bool addBusy: false
    property string addError: ""
    property string addStdout: ""
    property string addStderr: ""

    signal addCompleted(bool ok)

    function refresh(): void {
        statusProc.running = true;
        listProc.running = true;
    }

    function profileFor(name: string): var {
        return root.profiles.find(p => p.name === name) ?? null;
    }

    function sessionFor(name: string): var {
        return root.sessions[name] ?? null;
    }

    function _safeUnitName(name: string): string {
        return `jarvos-vpn-${String(name).replace(/[^A-Za-z0-9_.-]/g, "-")}`;
    }

    function _refreshSessionViews(): void {
        const all = [];
        const active = [];
        const errors = [];

        for (const name of Object.keys(root.sessions).sort()) {
            const session = root.sessions[name];
            if (!session)
                continue;

            const snapshot = {
                profile: name,
                server: session.server ?? "",
                phase: session.phase ?? "",
                stage: session.stage ?? "",
                promptLabel: session.promptLabel ?? "",
                errorText: session.errorText ?? ""
            };

            if (snapshot.phase !== "" || snapshot.stage === "error") {
                all.push(snapshot);
                if (snapshot.phase !== "")
                    active.push(snapshot);
                if (snapshot.stage === "error")
                    errors.push(snapshot);
            }
        }

        root.sessionViews = all;
        root.connectingSessionViews = active;
        root.errorSessionViews = errors;
    }

    function _addSession(name: string): var {
        if (name === undefined || name === null || name.length === 0)
            return null;

        if (root.sessions[name])
            return root.sessions[name];

        const session = vpnSessionComponent.createObject(root, { profile: name });
        if (!session)
            return null;

        session.onStateChanged.connect(root._refreshSessionViews);

        const next = Object.assign({}, root.sessions);
        next[name] = session;
        root.sessions = next;
        root._refreshSessionViews();
        return session;
    }

    function _removeSession(name: string): void {
        const session = root.sessions[name];
        if (!session)
            return;

        session.cleanup();

        const next = Object.assign({}, root.sessions);
        delete next[name];
        root.sessions = next;
        root._refreshSessionViews();
    }

    function sessionIsBusyOrErrored(name: string): bool {
        const session = root.sessionFor(name);
        return !!session && (session.phase !== "" || session.stage === "error");
    }

    function startConnect(name: string): void {
        const session = root._addSession(name);
        if (!session)
            return;
        session.start();
    }

    // The user's answer to the current prompt. Written straight to the
    // client's stdin; never stored.
    function answer(name: string, text: string): void {
        const session = root.sessionFor(name);
        if (!session)
            return;
        session.answer(text);
    }

    function cancel(name: string): void {
        const session = root.sessionFor(name);
        if (session)
            session.cancel();
    }

    function dismissError(name: string): void {
        const session = root.sessionFor(name);
        if (!session)
            return;
        session.dismissError();
        root._removeSession(name);
    }

    function addProfile(name: string, vendor: string, server: string, user: string): void {
        if (name.trim() === "" || vendor.trim() === "" || server.trim() === "")
            return;
        if (root.addBusy)
            return;

        root.addError = "";
        root.addStdout = "";
        root.addStderr = "";
        addProc.command = ["jarvos-vpn", "add", "--name", name.trim(), "--vendor", vendor.trim(), "--server", server.trim(), "--auth", "sso"];
        if (user.trim() !== "")
            addProc.command.push("--user", user.trim());
        root.addBusy = true;
        addProc.running = true;
    }

    function disconnect(profile: string): void {
        const session = root.sessionFor(profile);
        if (session && session.isRunning)
            session.cancel();

        Quickshell.execDetached(["jarvos-vpn", "disconnect", profile]);
        root.refresh();
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc

        command: ["jarvos-vpn", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text);
                    root.connected = obj.connected === true;
                    root.tunnels = obj.tunnels ?? [];
                } catch (e) {
                    root.connected = false;
                    root.tunnels = [];
                }

            // The profile being connected has appeared: authentication is
            // over, whatever the client still prints.
            const sessions = root.sessionViews.slice();
            if (sessions.length > 0) {
                for (let i = 0; i < sessions.length; i++) {
                    const profile = sessions[i]?.profile;
                    if (profile && root.connectedProfiles.includes(profile))
                        root._removeSession(profile);
                }
            }
            }
        }
    }

    Process {
        id: listProc

        command: ["jarvos-vpn", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.profiles = JSON.parse(text);
                } catch (e) {
                    root.profiles = [];
                }
            }
        }
    }

    Process {
        id: addProc

        onExited: (code, status) => {
            const message = (root.addStderr.trim() || root.addStdout.trim()) || `jarvos-vpn add failed (${code})`;
            root.addBusy = false;
            if (code !== 0) {
                root.addError = message;
                root.addCompleted(false);
                return;
            }

            root.addError = "";
            root.addCompleted(true);
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: root.addStdout = text
        }

        stderr: StdioCollector {
            onStreamFinished: root.addStderr = text
        }
    }

    component VpnSession: QtObject {
        id: session

        required property string profile
        property string server: ""
        property string phase: ""
        property string stage: ""
        property string promptLabel: ""
        property string errorText: ""
        property string transcript: ""
        property string pendingCommand: ""
        property bool isRunning: phase !== ""
        property bool cancelRequested: false

        signal stateChanged()

        function lastMeaningfulLine(): string {
            const lines = session.transcript.split("\n").map(l => l.trim()).filter(l => l.length > 0);
            for (let i = lines.length - 1; i >= 0; i--) {
                const l = lines[i];
                if (/^\*+$/.test(l))
                    continue;
                if (/^(GET|POST) https|^Connected to |^SSL negotiation|^Attempting|^Got |^Using /i.test(l))
                    continue;
                if (/:$/.test(l))
                    continue;
                return l;
            }
            return "The client exited without saying why";
        }

        function examine(full: string): void {
            if (full.length === 0)
                return;

            session.transcript = full.slice(-2000);

            if (session.phase !== "auth")
                return;

            const tail = full.replace(/\s+$/, "");
            const m = tail.match(/([A-Za-z][A-Za-z ()\\/-]{0,40}):$/);
            if (m) {
                session.promptLabel = m[1];
                session.phase = "prompt";
                session.stage = "prompt";
                session.stateChanged();
                root._refreshSessionViews();
                return;
            }

            if (/browser|Open the following URL|authentication URL/i.test(tail))
                session.stage = "browser";
            else if (/Connected as |Configured as |ESP session|DTLS|Established|Connected to the gateway/i.test(tail))
                session.stage = "tunnel";
            else if (/Connected to |GET https|POST https|SSL negotiation/i.test(tail))
                session.stage = "portal";
            session.stateChanged();
            root._refreshSessionViews();
        }

        function start(): void {
            if (session.phase !== "")
                return;

            const p = root.profileFor(session.profile);
            session.server = p?.server ?? "";
            session.transcript = "";
            session.promptLabel = "";
            session.errorText = "";
            session.phase = "auth";
            session.stage = "portal";
            session.cancelRequested = false;
            session.stateChanged();
            root._refreshSessionViews();

            // jarvos-vpn owns vendor dispatch; --dry-run prints the command
            // instead of running it, so this process can own its stdin.
            commandProc.command = ["jarvos-vpn", "connect", session.profile, "--dry-run"];
            commandProc.running = true;
        }

        // The user's answer to the current prompt. Written straight to the
        // client's stdin; never stored.
        function answer(text: string): void {
            if (text.length === 0 || !conn.running)
                return;
            conn.write(text + "\n");
            session.phase = "auth";
            session.stage = "tunnel";
            session.promptLabel = "";
            session.stateChanged();
            root._refreshSessionViews();
        }

        function cancel(): void {
            if (!conn.running) {
                session.phase = "";
                session.stage = "";
                session.promptLabel = "";
                session.errorText = "";
                session.stateChanged();
                root._removeSession(session.profile);
                return;
            }

            session.cancelRequested = true;
            conn.signal(15);
        }

        function dismissError(): void {
            session.phase = "";
            session.stage = "";
            session.promptLabel = "";
            session.errorText = "";
            session.stateChanged();
            root._refreshSessionViews();
        }

        function cleanup(): void {
            if (commandProc.running)
                commandProc.running = false;
            if (pwProc.running)
                pwProc.running = false;
            if (conn.running)
                conn.signal(15);
        }

        readonly property Process commandProc: Process {

            stdout: StdioCollector {
                onStreamFinished: {
                    const line = text.trim();
                    if (line.length === 0) {
                        session.phase = "";
                        session.stage = "error";
                        session.errorText = "jarvos-vpn could not build a command for this profile";
                        session.stateChanged();
                        root._refreshSessionViews();
                        return;
                    }
                    session.pendingCommand = line;
                    pwProc.running = true;
                }
            }
        }

        // The password goes keyring → this process → the client's stdin.
        // It is held only long enough to be written and never assigned to a
        // property.
        readonly property Process pwProc: Process {

            command: ["secret-tool", "lookup", "service", "jarvos-vpn", "profile", session.profile]
            stdout: StdioCollector {
                onStreamFinished: {
                    // Start the client first, then hand it the password. Doing
                    // both at once raced: the write landed before stdin was open
                    // and was lost.
                    // A transient service survives QuickShell reloads. --pipe keeps
                    // stdin available for password profiles without forcing a PTY;
                    // GlobalProtect's external browser callback does not need one.
                    conn.command = [
                        "systemd-run",
                        "--user",
                        "--quiet",
                        "--collect",
                        "--wait",
                        "--pipe",
                        `--unit=${root._safeUnitName(session.profile)}`,
                        "--",
                        "sh",
                        "-c",
                        session.pendingCommand
                    ];
                    conn.running = true;
                    if (text.length > 0)
                        conn.write(text.replace(/\n$/, "") + "\n");
                }
            }
        }

        readonly property Process conn: Process {

            stdinEnabled: true

            stdout: StdioCollector {
                waitForEnd: false
                onTextChanged: session.examine(text)
            }
            stderr: StdioCollector {
                waitForEnd: false
                onTextChanged: session.examine(text)
            }

            onExited: (code, status) => {
                const wasLoggingIn = session.phase !== "";
                const cancelled = session.cancelRequested;
                session.cancelRequested = false;
                session.phase = "";
                session.promptLabel = "";
                session.stateChanged();
                root._refreshSessionViews();

                if (cancelled) {
                    session.stage = "";
                    session.errorText = "";
                    root._removeSession(session.profile);
                    root.refresh();
                    return;
                }

                if (wasLoggingIn && code !== 0) {
                    session.stage = "error";
                    session.errorText = session.lastMeaningfulLine();
                    session.stateChanged();
                    root._refreshSessionViews();
                    root.refresh();
                    return;
                }

                if (wasLoggingIn) {
                    session.stage = "";
                    session.stateChanged();
                    root._removeSession(session.profile);
                    root.refresh();
                    return;
                }
            }
        }
    }

    Component {
        id: vpnSessionComponent

        VpnSession {}
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.connectingSessionViews.length > 0 || root.connected
        onTriggered: root.refresh()
    }
}
