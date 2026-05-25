pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Item wrapper

    readonly property int contentWidth: 300

    property bool running: false
    property string ip4: ""
    property string dnsName: ""
    property int peers: 0
    property string exitNode: ""
    property bool copied: false

    implicitWidth: contentWidth
    implicitHeight: child.implicitHeight

    function refresh(): void {
        statusProc.running = true;
    }

    Component.onCompleted: refresh()

    // Fresh status whenever the popout is (re)opened.
    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "tailscale")
                root.refresh();
        }
    }

    Process {
        id: statusProc

        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(text);
                    root.running = (obj.BackendState === "Running");
                    const ips = obj.TailscaleIPs || [];
                    root.ip4 = ips.find(ip => ip.indexOf(":") === -1) || "";
                    root.dnsName = (obj.Self && obj.Self.DNSName) ? obj.Self.DNSName.replace(/\.$/, "") : "";
                    root.peers = obj.Peer ? Object.keys(obj.Peer).length : 0;
                    root.exitNode = (obj.ExitNodeStatus && obj.ExitNodeStatus.ID) ? obj.ExitNodeStatus.ID : "";
                } catch (e) {
                    root.running = false;
                }
            }
        }
    }

    // Re-poll shortly after a connect/disconnect so the popout reflects the new state.
    Timer {
        id: settleTimer
        interval: 1500
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: copiedTimer
        interval: 1200
        repeat: false
        onTriggered: root.copied = false
    }

    ColumnLayout {
        id: child

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        // Header: status icon + name + connection state
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "hub"
                color: root.running ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.large
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Tailscale"
                    font.pointSize: Appearance.font.size.normal
                    font.bold: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.running ? (root.dnsName || "Connected") : "Disconnected"
                    color: root.running ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                    font.pointSize: Appearance.font.size.smaller
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            Layout.bottomMargin: Appearance.spacing.small / 2
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Copy IP
        MenuRow {
            icon: "content_copy"
            label: root.copied ? "Copied!" : "Copy IP"
            trailing: root.ip4
            visible: root.ip4.length > 0
            onTriggered: {
                if (root.ip4.length === 0)
                    return;
                Quickshell.execDetached(["wl-copy", root.ip4]);
                root.copied = true;
                copiedTimer.restart();
            }
        }

        // Connect / Disconnect (operator=user → no sudo)
        MenuRow {
            icon: root.running ? "link_off" : "link"
            label: root.running ? "Disconnect" : "Connect"
            accent: root.running ? Colours.palette.m3error : Colours.palette.m3primary
            onTriggered: {
                Quickshell.execDetached(["tailscale", root.running ? "down" : "up"]);
                settleTimer.restart();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Info footer
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            text: `Peers: ${root.peers} · Exit node: ${root.exitNode.length > 0 ? root.exitNode : "none"}`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            elide: Text.ElideRight
        }
    }

    // Clickable menu row with ripple (StateLayer), icon, label and optional trailing text.
    component MenuRow: Rectangle {
        id: menuRow

        property string icon
        property string label
        property string trailing: ""
        property color accent: Colours.palette.m3onSurface
        signal triggered()

        Layout.fillWidth: true
        implicitHeight: menuRowLayout.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.small
        color: "transparent"

        StateLayer {
            color: menuRow.accent
            radius: menuRow.radius

            function onClicked(): void {
                menuRow.triggered();
            }
        }

        RowLayout {
            id: menuRowLayout

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: menuRow.icon
                color: menuRow.accent
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: menuRow.label
                color: menuRow.accent
                font.pointSize: Appearance.font.size.smaller
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                visible: menuRow.trailing.length > 0
                text: menuRow.trailing
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
