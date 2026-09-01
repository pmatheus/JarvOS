pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Appearance.padding.normal

    // Set by Bar.qml so the Tailscale chip can drive the bar popout system.
    property var bar: null

    property bool vpnConnected: false
    property string externalIp: "..."
    property string internalIp: "..."

    // The real VPN tunnel — GlobalProtect today, openconnect later. Distinct from
    // vpnConnected, which is Tailscale's BackendState and drives the chip above.
    property string tunnelIp: ""
    property string tunnelName: ""
    readonly property bool tunnelUp: tunnelIp !== ""

    // Tailscale details, parsed from the existing `tailscale status --json` poll.
    property string tsIp4: ""
    property string tsDnsName: ""
    property int tsPeers: 0
    property string tsExitNode: ""

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Appearance.rounding.full

    // Internal/external IP change rarely; the external IP uses a network round-trip
    // (curl), so keep it on a slow cadence.
    Timer {
        id: refreshTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            internalIpProc.running = true;
            externalIpProc.running = true;
        }
    }

    // Tailscale state (connect/disconnect) must reflect quickly. `tailscale status`
    // is a cheap local call, so poll it on a short cadence so toggling from the
    // popout (or anywhere) updates the chip within a few seconds, not 30.
    Timer {
        id: vpnTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            vpnCheckProc.running = true;
            tunnelProc.running = true;
        }
    }

    // The VPN chip reports the real tunnel, not Tailscale. Tailscale has its own
    // chip and its own address; before this, both were driven by BackendState,
    // so the key said "VPN" whenever Tailscale was up and said nothing at all
    // about GlobalProtect.
    //
    // Matched on link kind rather than name: GlobalProtect is tun0 today, but
    // openconnect, WireGuard and a second tunnel all name themselves differently
    // and a name match would miss every one of them. tailscale0 is the same kind,
    // hence the explicit exclusion.
    Process {
        id: tunnelProc

        command: ["ip", "-j", "-d", "addr", "show"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                let ip = "";
                try {
                    for (const link of JSON.parse(text)) {
                        if (link.ifname === "tailscale0")
                            continue;
                        const kind = link.linkinfo?.info_kind ?? "";
                        if (!["tun", "tap", "wireguard", "ppp"].includes(kind))
                            continue;
                        const addr = link.addr_info?.find(a => a.family === "inet");
                        if (!addr)
                            continue;
                        name = link.ifname;
                        ip = addr.local;
                        break;
                    }
                } catch (e) {
                    // A malformed listing means unknown, not disconnected: leaving
                    // the previous address up would claim a tunnel we cannot see.
                }
                root.tunnelName = name;
                root.tunnelIp = ip;
            }
        }
    }

    Process {
        id: vpnCheckProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text);
                    root.vpnConnected = (obj.BackendState === "Running");
                    const ips = obj.TailscaleIPs || [];
                    root.tsIp4 = ips.find(ip => ip.indexOf(":") === -1) || "";
                    root.tsDnsName = (obj.Self && obj.Self.DNSName) ? obj.Self.DNSName.replace(/\.$/, "") : "";
                    root.tsPeers = obj.Peer ? Object.keys(obj.Peer).length : 0;
                    root.tsExitNode = (obj.ExitNodeStatus && obj.ExitNodeStatus.ID) ? obj.ExitNodeStatus.ID : "";
                } catch (e) {
                    root.vpnConnected = false;
                }
            }
        }
        // NOTE: stderr is intentionally not used to decide connection state.
        // `tailscale status --json` emits non-fatal warnings there (e.g. client/
        // daemon version skew), which must not override the authoritative
        // BackendState parsed from stdout above.
    }

    Process {
        id: internalIpProc
        command: ["sh", "-c", "ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \\K[\\d.]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ip = text.trim();
                if (ip.length > 0)
                    root.internalIp = ip;
            }
        }
    }

    Process {
        id: externalIpProc
        command: ["sh", "-c", "curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo '?'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ip = text.trim();
                if (ip.length > 0)
                    root.externalIp = ip;
            }
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        // Tailscale chip — icon + 100.x IP, click opens the Tailscale popout
        Item {
            id: tsChip

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: tsRow.implicitWidth
            implicitHeight: tsRow.implicitHeight

            RowLayout {
                id: tsRow
                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                MaterialIcon {
                    text: "hub"
                    color: root.vpnConnected ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.vpnConnected ? (root.tsIp4 || "…") : "off"
                    font.pointSize: Appearance.font.size.smaller
                    font.family: Appearance.font.family.mono
                    font.bold: true
                    color: root.vpnConnected ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    const popouts = root.bar?.popouts;
                    if (!popouts)
                        return;
                    if (popouts.hasCurrent && popouts.currentName === "tailscale") {
                        popouts.hasCurrent = false;
                    } else {
                        popouts.currentName = "tailscale";
                        popouts.currentCenter = tsChip.mapToItem(root.bar, tsChip.width / 2, 0).x;
                        popouts.hasCurrent = true;
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1
            Layout.preferredHeight: layout.height * 0.4
            color: root.colour
            opacity: 0.15
        }

        // VPN icon
        MaterialIcon {
            text: root.tunnelUp ? "vpn_key" : "vpn_key_off"
            color: root.tunnelUp ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        // VPN label
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.tunnelUp ? root.tunnelIp : "OFF"
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            font.bold: true
            color: root.tunnelUp ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        // Separator
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1
            Layout.preferredHeight: layout.height * 0.4
            color: root.colour
            opacity: 0.15
        }

        // External IP
        MaterialIcon {
            text: "public"
            color: root.colour
            opacity: 0.6
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.externalIp
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.8
        }

        // Separator
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1
            Layout.preferredHeight: layout.height * 0.4
            color: root.colour
            opacity: 0.15
        }

        // Internal IP
        MaterialIcon {
            text: "lan"
            color: root.colour
            opacity: 0.6
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.internalIp
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.8
        }
    }
}
