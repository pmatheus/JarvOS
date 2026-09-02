pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The VPN menu. Pure view: the connection itself lives in the VpnTunnels
// singleton, because this popout is unloaded whenever the menu closes and
// anything it owned — an openconnect process included — would die with it.
Item {
    id: root

    required property Item wrapper

    readonly property int contentWidth: 340
    property bool copied: false

    implicitWidth: contentWidth
    implicitHeight: child.implicitHeight

    Component.onCompleted: VpnTunnels.refresh()

    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "vpn")
                VpnTunnels.refresh();
        }
    }

    Timer {
        id: copiedTimer

        interval: 1200
        onTriggered: root.copied = false
    }

    ColumnLayout {
        id: child

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: VpnTunnels.connected ? "vpn_key" : "vpn_key_off"
                color: VpnTunnels.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.large
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "VPN"
                    font.pointSize: Appearance.font.size.normal
                    font.bold: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (VpnTunnels.phase === "prompt")
                            return `${VpnTunnels.activeProfile} — ${VpnTunnels.promptLabel}`;
                        if (VpnTunnels.phase === "auth")
                            return `${VpnTunnels.activeProfile} — authenticating…`;
                        if (!VpnTunnels.connected)
                            return "Disconnected";
                        return VpnTunnels.tunnels.map(t => `${t.profile ?? t.iface} ${t.ip}`).join("  ·  ");
                    }
                    color: VpnTunnels.connected ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
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

        // The second factor. Masked, and it never touches a command line: the
        // value goes straight to the client's stdin.
        ColumnLayout {
            Layout.fillWidth: true
            visible: VpnTunnels.phase === "prompt"
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: `${VpnTunnels.promptLabel}:`
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.smaller
            }

            TextField {
                id: codeField

                Layout.fillWidth: true
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                placeholderText: "code"
                color: Colours.palette.m3onSurface
                font.family: Appearance.font.family.mono

                background: Rectangle {
                    color: Colours.palette.m3surfaceContainerHighest
                    radius: Appearance.rounding.small
                }

                onVisibleChanged: if (visible)
                    forceActiveFocus()

                onAccepted: {
                    VpnTunnels.answer(text);
                    text = "";
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                MenuRow {
                    icon: "send"
                    label: "Send"
                    accent: Colours.palette.m3primary
                    onTriggered: codeField.accepted()
                }

                MenuRow {
                    icon: "close"
                    label: "Cancel"
                    accent: Colours.palette.m3error
                    onTriggered: VpnTunnels.cancel()
                }
            }
        }

        // What the client is saying. Without this a rejected code just brings
        // the prompt back and the user is left guessing why.
        StyledText {
            Layout.fillWidth: true
            visible: VpnTunnels.phase !== "" && VpnTunnels.transcript.length > 0
            text: VpnTunnels.transcript.replace(/\*+/g, "").trim().split("\n").filter(l => l.trim().length > 0).slice(-3).join("\n")
            color: Colours.palette.m3onSurfaceVariant
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WrapAnywhere
            opacity: 0.8
        }

        StyledText {
            Layout.fillWidth: true
            visible: VpnTunnels.phase === "auth"
            text: "Waiting for the portal…"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
        }

        // One block per live tunnel. Disconnect names the profile, because with
        // two cases up at once "disconnect" alone would have to guess — and the
        // wrapper refuses to.
        Repeater {
            model: VpnTunnels.phase === "" ? VpnTunnels.tunnels : []

            ColumnLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 0

                MenuRow {
                    icon: "content_copy"
                    label: (modelData.profile ?? modelData.iface)
                    trailing: modelData.ip
                    onTriggered: {
                        Quickshell.execDetached(["wl-copy", modelData.ip]);
                        root.copied = true;
                        copiedTimer.restart();
                    }
                }

                MenuRow {
                    icon: "link_off"
                    label: `Disconnect ${modelData.profile ?? modelData.iface}`
                    accent: Colours.palette.m3error
                    onTriggered: VpnTunnels.disconnect(modelData.profile ?? "")
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            visible: VpnTunnels.phase === "" && VpnTunnels.profiles.some(p => !VpnTunnels.connectedProfiles.includes(p.name))
            text: VpnTunnels.connected ? "Also connect" : "Connect to"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
        }

        Repeater {
            model: VpnTunnels.phase !== "" ? [] : VpnTunnels.profiles.filter(p => !VpnTunnels.connectedProfiles.includes(p.name))

            MenuRow {
                required property var modelData

                icon: "vpn_lock"
                label: modelData.name ?? ""
                trailing: modelData.vendor ?? ""
                onTriggered: VpnTunnels.startConnect(modelData.name)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: VpnTunnels.profiles.length === 0
            text: "No profiles yet — add one with\njarvos-vpn add"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WordWrap
        }
    }

    component MenuRow: Rectangle {
        id: menuRow

        property string icon
        property string label
        property string trailing: ""
        property color accent: Colours.palette.m3onSurface
        signal triggered

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
