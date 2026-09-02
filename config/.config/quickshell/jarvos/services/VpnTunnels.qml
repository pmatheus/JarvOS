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

    // "" idle · "auth" client running · "prompt" waiting on the user
    property string phase: ""
    // What the client is doing, read off its output so the menu can say it
    // in one line instead of showing the raw log:
    // "" · "portal" · "prompt" · "tunnel" · "error"
    property string stage: ""
    property string activeProfile: ""
    property string activeServer: ""
    property string promptLabel: ""
    property string errorText: ""
    property string transcript: ""
    property string pendingCommand: ""
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

    // Everything openconnect asks for after the password is a second factor.
    // The prompt has no trailing newline, which is why the collectors read
    // incrementally rather than waiting for the stream to end. Takes the
    // collector's whole text: an earlier version diffed against a truncated
    // copy and the offsets drifted, so the prompt was never seen.
    function examine(full: string): void {
        if (full.length === 0)
            return;

        root.transcript = full.slice(-2000);

        if (root.phase !== "auth")
            return;

        const tail = full.replace(/\s+$/, "");
        const m = tail.match(/([A-Za-z][A-Za-z ()\/-]{0,40}):$/);
        if (m) {
            root.promptLabel = m[1];
            root.phase = "prompt";
            root.stage = "prompt";
            return;
        }

        if (/browser|Open the following URL|authentication URL/i.test(tail))
            root.stage = "browser";
        else if (/Connected as |Configured as |ESP session|DTLS|Established|Connected to the gateway/i.test(tail))
            root.stage = "tunnel";
        else if (/Connected to |GET https|POST https|SSL negotiation/i.test(tail))
            root.stage = "portal";
    }

    // The one line worth showing when the client gives up: the last line
    // that is not transport chatter or a masked echo.
    function lastMeaningfulLine(): string {
        const lines = root.transcript.split("\n").map(l => l.trim()).filter(l => l.length > 0);
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

    function startConnect(name: string): void {
        if (root.phase !== "")
            return;
        const p = profileFor(name);
        root.activeProfile = name;
        root.activeServer = p?.server ?? "";
        root.transcript = "";
        root.promptLabel = "";
        root.errorText = "";
        root.phase = "auth";
        root.stage = "portal";
        // jarvos-vpn owns the vendor dispatch; --dry-run prints the command
        // instead of running it, so this process can own its stdin.
        commandProc.command = ["jarvos-vpn", "connect", name, "--dry-run"];
        commandProc.running = true;
    }

    // The user's answer to the current prompt. Written straight to the
    // client's stdin; never stored.
    function answer(text: string): void {
        if (text.length === 0 || !conn.running)
            return;
        conn.write(text + "\n");
        root.phase = "auth";
        root.stage = "tunnel";
        root.promptLabel = "";
    }

    function cancel(): void {
        if (conn.running)
            conn.signal(15);
        root.phase = "";
        root.stage = "";
        root.promptLabel = "";
        root.errorText = "";
        root.activeProfile = "";
    }

    function dismissError(): void {
        root.stage = "";
        root.errorText = "";
        root.activeProfile = "";
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
        if (profile === root.activeProfile && conn.running)
            conn.signal(15);
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
                if (root.phase !== "" && root.connectedProfiles.includes(root.activeProfile)) {
                    root.phase = "";
                    root.stage = "";
                    root.activeProfile = "";
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
        id: commandProc

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line.length === 0) {
                    root.phase = "";
                    root.stage = "error";
                    root.errorText = "jarvos-vpn could not build a command for this profile";
                    return;
                }
                root.pendingCommand = line;
                pwProc.running = true;
            }
        }
    }

    // The password goes keyring → this process → the client's stdin. It is
    // held only long enough to be written and never assigned to a property.
    Process {
        id: pwProc

        command: ["secret-tool", "lookup", "service", "jarvos-vpn", "profile", root.activeProfile]
        stdout: StdioCollector {
            onStreamFinished: {
                // Start the client first, then hand it the password. Doing
                // both at once raced: the write landed before stdin was open
                // and was lost.
                // Own scope unit: the shell's service is KillMode=control-group,
                // so a plain child would die with every quickshell restart.
                conn.command = ["systemd-run", "--user", "--scope", "--quiet", "--collect", `--unit=jarvos-vpn-${root.activeProfile}`, "--", "sh", "-c", root.pendingCommand];
                conn.running = true;
                if (text.length > 0)
                    conn.write(text.replace(/\n$/, "") + "\n");
            }
        }
    }

    Process {
        id: conn

        stdinEnabled: true

        stdout: StdioCollector {
            waitForEnd: false
            onTextChanged: root.examine(text)
        }
        stderr: StdioCollector {
            waitForEnd: false
            onTextChanged: root.examine(text)
        }

        onExited: (code, status) => {
            const wasLoggingIn = root.phase !== "";
            root.phase = "";
            root.promptLabel = "";
            if (wasLoggingIn && code !== 0) {
                root.stage = "error";
                root.errorText = root.lastMeaningfulLine();
            } else if (wasLoggingIn) {
                root.stage = "";
            }
            root.refresh();
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

    // The tunnel appears a moment after the client authenticates, so poll
    // rather than assume.
    Timer {
        interval: 2000
        repeat: true
        running: root.phase !== "" || root.connected
        onTriggered: root.refresh()
    }
}
