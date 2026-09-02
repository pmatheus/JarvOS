pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The case-VPN connection engine behind the bar's VPN menu.
//
// This is a singleton, and that is load-bearing: the bar popouts are Loaders
// that unload when the menu closes, and a Process is killed with the item that
// owns it. The first version of the menu ran openconnect inside the popout, and
// the tunnel died the moment the mouse left the menu. Here the connection
// outlives any menu.
//
// It runs the client rather than a terminal, and that is a security property:
// a terminal echoes what is typed, so a 2FA code — and, on a retry, the
// password — end up on screen and in scrollback. A Process has no tty, so
// nothing is echoed, and the menu's field masks what the user types.
//
// Secrets never reach a command line. The password goes keyring → stdin, and
// openconnect is given --passwd-on-stdin; argv holds only server, protocol
// and username.
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
    property string activeProfile: ""
    property string promptLabel: ""
    property string transcript: ""
    property string pendingCommand: ""

    function refresh(): void {
        statusProc.running = true;
        listProc.running = true;
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
        }
    }

    function startConnect(name: string): void {
        if (root.phase !== "")
            return;
        root.activeProfile = name;
        root.transcript = "";
        root.promptLabel = "";
        root.phase = "auth";
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
        root.promptLabel = "";
    }

    function cancel(): void {
        if (conn.running)
            conn.signal(15);
        root.phase = "";
        root.promptLabel = "";
        root.activeProfile = "";
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
                if (root.phase !== "" && root.connectedProfiles.includes(root.activeProfile))
                    root.phase = "";
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
                conn.command = ["sh", "-c", root.pendingCommand];
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

        onExited: {
            root.phase = "";
            root.promptLabel = "";
            root.refresh();
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
