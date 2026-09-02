pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// The VPN menu. Pure view: the connection itself lives in the VpnTunnels
// singleton, because this popout is unloaded whenever the menu closes and
// anything it owned — an openconnect process included — would die with it.
Item {
    id: root

    required property Item wrapper

    readonly property int contentWidth: 340
    property string copiedIp: ""

    readonly property bool loggingIn: VpnTunnels.phase !== ""
    readonly property bool failed: VpnTunnels.stage === "error"
    readonly property var available: VpnTunnels.profiles.filter(p => !VpnTunnels.connectedProfiles.includes(p.name))
    property bool addingProfile: false
    property string addName: ""
    property string addVendor: ""
    property string addServer: ""
    property string addUser: ""

    readonly property bool canAddProfile: addName.trim().length > 0 && addVendor.trim().length > 0 && addServer.trim().length > 0

    implicitWidth: contentWidth
    implicitHeight: child.implicitHeight

    function vendorIcon(vendor: string): string {
        switch (vendor) {
        case "globalprotect":
            return "shield";
        case "fortinet":
            return "security";
        case "checkpoint":
            return "verified_user";
        default:
            return "vpn_lock";
        }
    }

    function vendorName(vendor: string): string {
        switch (vendor) {
        case "globalprotect":
            return "GlobalProtect";
        case "fortinet":
            return "Fortinet";
        case "anyconnect":
            return "AnyConnect";
        case "checkpoint":
            return "Check Point";
        default:
            return vendor ?? "";
        }
    }

    function stageText(): string {
        switch (VpnTunnels.stage) {
        case "portal":
            return `Contacting ${VpnTunnels.activeServer}…`;
        case "prompt":
            return "Enter your authenticator code";
        case "browser":
            return "Finish signing in with your browser";
        case "tunnel":
            return "Bringing the tunnel up…";
        default:
            return "";
        }
    }

    Component.onCompleted: VpnTunnels.refresh()

    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "vpn")
                VpnTunnels.refresh();
        }
    }

    Connections {
        target: VpnTunnels
        function onAddCompleted(ok: bool): void {
            if (ok) {
                root.addingProfile = false;
                root.addName = "";
                root.addVendor = "";
                root.addServer = "";
                root.addUser = "";
            }
        }
    }

    function openAddProfile(): void {
        root.addingProfile = true;
        root.addName = "";
        root.addVendor = "";
        root.addServer = "";
        root.addUser = "";
        VpnTunnels.addError = "";
        addNameField.forceActiveFocus();
    }

    function cancelAddProfile(): void {
        root.addingProfile = false;
        root.addName = "";
        root.addVendor = "";
        root.addServer = "";
        root.addUser = "";
        VpnTunnels.addError = "";
    }

    function submitAddProfile(): void {
        if (!root.canAddProfile || VpnTunnels.addBusy)
            return;
        VpnTunnels.addProfile(root.addName, root.addVendor, root.addServer, root.addUser);
    }

    Timer {
        id: copiedTimer

        interval: 1500
        onTriggered: root.copiedIp = ""
    }

    ColumnLayout {
        id: child

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        // Header
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
                        const n = VpnTunnels.tunnels.length;
                        if (n === 0)
                            return "Not connected";
                        return n === 1 ? "1 tunnel up" : `${n} tunnels up`;
                    }
                    color: VpnTunnels.connected ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3error
                    font.pointSize: Appearance.font.size.smaller
                }
            }
        }

        // Login in progress
        Card {
            visible: root.loggingIn
            tint: Colours.palette.m3surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    CircularIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Appearance.font.size.normal * 1.6
                        strokeWidth: 2
                        running: root.loggingIn && VpnTunnels.stage !== "prompt" && VpnTunnels.stage !== "browser"
                        visible: running
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        visible: VpnTunnels.stage === "prompt" || VpnTunnels.stage === "browser"
                        text: VpnTunnels.stage === "browser" ? "open_in_browser" : "password"
                        color: Colours.palette.m3primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: VpnTunnels.activeProfile
                            font.bold: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.stageText()
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Appearance.font.size.smaller
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: VpnTunnels.cancel()
                    }
                }

                // The second factor. Masked, and it never touches a command
                // line: the value goes straight to the client's stdin.
                RowLayout {
                    Layout.fillWidth: true
                    visible: VpnTunnels.stage === "prompt"
                    spacing: Appearance.spacing.small

                    StyledTextField {
                        id: codeField

                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        placeholderText: `${VpnTunnels.promptLabel}…`
                        font.family: Appearance.font.family.mono

                        onVisibleChanged: if (visible)
                            forceActiveFocus()

                        onAccepted: {
                            VpnTunnels.answer(text);
                            text = "";
                        }
                    }

                    IconButton {
                        icon: "send"
                        disabled: codeField.text.length === 0
                        onClicked: codeField.accepted()
                    }
                }
            }
        }

        // Login failed
        Card {
            visible: root.failed && !root.loggingIn
            tint: Colours.palette.m3errorContainer

            RowLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "error"
                    color: Colours.palette.m3onErrorContainer
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: `${VpnTunnels.activeProfile} did not connect`
                        color: Colours.palette.m3onErrorContainer
                        font.bold: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: VpnTunnels.errorText
                        color: Colours.palette.m3onErrorContainer
                        font.pointSize: Appearance.font.size.smaller
                        wrapMode: Text.WordWrap
                    }
                }

                IconButton {
                    icon: "refresh"
                    type: IconButton.Text
                    activeColour: Colours.palette.m3onErrorContainer
                    onClicked: {
                        const name = VpnTunnels.activeProfile;
                        VpnTunnels.dismissError();
                        VpnTunnels.startConnect(name);
                    }
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    activeColour: Colours.palette.m3onErrorContainer
                    onClicked: VpnTunnels.dismissError()
                }
            }
        }

        // One card per live tunnel. Disconnect names the profile, because
        // with two cases up at once "disconnect" alone would have to guess.
        Repeater {
            model: VpnTunnels.tunnels

            Card {
                id: tunnelCard

                required property var modelData
                readonly property string name: modelData.profile ?? modelData.iface
                readonly property var profile: VpnTunnels.profileFor(modelData.profile ?? "")

                tint: Colours.palette.m3primaryContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.normal

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.vendorIcon(tunnelCard.profile?.vendor ?? "")
                        color: Colours.palette.m3onPrimaryContainer
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: tunnelCard.name
                            color: Colours.palette.m3onPrimaryContainer
                            font.bold: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: tunnelCard.modelData.ip
                            color: Colours.palette.m3onPrimaryContainer
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: root.copiedIp === tunnelCard.modelData.ip ? "check" : "content_copy"
                        type: IconButton.Text
                        activeColour: Colours.palette.m3onPrimaryContainer
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", tunnelCard.modelData.ip]);
                            root.copiedIp = tunnelCard.modelData.ip;
                            copiedTimer.restart();
                        }
                    }

                    IconButton {
                        icon: "link_off"
                        type: IconButton.Text
                        activeColour: Colours.palette.m3error
                        onClicked: VpnTunnels.disconnect(tunnelCard.modelData.profile ?? "")
                    }
                }
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            visible: !root.loggingIn
            icon: root.addingProfile ? "close" : "add"
            text: root.addingProfile ? "Hide add profile" : "Add profile"
            type: IconTextButton.Text
            activeColour: Colours.palette.m3primary
            onClicked: root.addingProfile ? root.cancelAddProfile() : root.openAddProfile()
        }

        Card {
            Layout.fillWidth: true
            visible: root.addingProfile
            tint: Colours.palette.m3surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                StyledText {
                    text: "Add VPN profile"
                    font.bold: true
                    font.pointSize: Appearance.font.size.smaller
                }

                StyledTextField {
                    id: addNameField

                    Layout.fillWidth: true
                    text: root.addName
                    placeholderText: "Profile name (e.g. mte)"
                    onTextChanged: root.addName = text
                }

                StyledTextField {
                    Layout.fillWidth: true
                    text: root.addVendor
                    placeholderText: "Vendor (e.g. panorama)"
                    onTextChanged: root.addVendor = text
                }

                StyledTextField {
                    Layout.fillWidth: true
                    text: root.addServer
                    placeholderText: "Server hostname"
                    onTextChanged: root.addServer = text
                }

                StyledTextField {
                    Layout.fillWidth: true
                    text: root.addUser
                    placeholderText: "Username (optional)"
                    onTextChanged: root.addUser = text
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    CircularIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        visible: VpnTunnels.addBusy
                        running: visible
                    }

                    IconButton {
                        icon: "check"
                        type: IconButton.Text
                        disabled: !root.canAddProfile || VpnTunnels.addBusy
                        onClicked: root.submitAddProfile()
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: root.cancelAddProfile()
                    }
                }

                StyledText {
                    visible: VpnTunnels.addError.length > 0
                    Layout.fillWidth: true
                    text: VpnTunnels.addError
                    color: Colours.palette.m3error
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Profiles that can still be connected
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            visible: !root.loggingIn && root.available.length > 0
            text: VpnTunnels.connected ? "Also connect" : "Connect"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
        }

        Repeater {
            model: root.loggingIn ? [] : root.available

            MenuRow {
                required property var modelData

                icon: root.vendorIcon(modelData.vendor ?? "")
                label: modelData.name ?? ""
                trailing: root.vendorName(modelData.vendor ?? "")
                onTriggered: VpnTunnels.startConnect(modelData.name)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: VpnTunnels.profiles.length === 0
            text: "No profiles yet. Add one with jarvos-vpn add."
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.WordWrap
        }
    }

    component Card: StyledRect {
        property color tint

        Layout.fillWidth: true
        implicitHeight: children.length > 0 ? children[0].implicitHeight + Appearance.padding.normal * 2 : 0
        radius: Appearance.rounding.normal
        color: tint
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
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                visible: menuRow.trailing.length > 0
                text: menuRow.trailing
                font.pointSize: Appearance.font.size.smaller
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
