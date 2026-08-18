pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // id -> bool. Seeded from each module's `default:` the first time the
    // catalogue arrives, then owned by the user.
    property var selection: ({})
    property bool seeded

    readonly property var selectedIds: JarvosSetup.modules.filter(m => root.selection[m.id] && m.installed < m.packages).map(m => m.id)
    readonly property bool anyQueued: Object.keys(JarvosSetup.progress).length > 0
    readonly property bool selectedNeedsToolchain: JarvosSetup.modules.some(m => root.selection[m.id] && m.installed < m.packages && m.needs_toolchain === true)
    // "Create my profile" only makes sense once this machine is actually set
    // up: everything the user asked for is here, and nothing is still running.
    readonly property bool settled: !JarvosSetup.busy && !JarvosSync.running && root.selectedIds.length === 0 && JarvosSetup.modules.length > 0

    signal closeRequested

    function toggle(id: string): void {
        const next = Object.assign({}, root.selection);
        next[id] = !next[id];
        root.selection = next;
    }

    // The installer wizard's answer lives in /etc/jarvos-release and nothing
    // else reads it; honouring it here is the only way the user's choice
    // survives the reboot into stage 2.
    function seed(): void {
        if (root.seeded || JarvosSetup.modules.length === 0)
            return;
        const profile = JarvosSetup.installProfile;
        const next = {};
        for (const m of JarvosSetup.modules) {
            const wanted = profile === "full" || (profile === "apps" && m.id === "apps") || m["default"] === true;
            next[m.id] = wanted && m.installed < m.packages;
        }
        root.selection = next;
        root.seeded = true;
    }

    implicitWidth: 820
    implicitHeight: 840

    Component.onCompleted: seed()

    Connections {
        target: JarvosSetup

        function onModulesChanged(): void {
            root.seed();
        }
    }

    // A restore installs packages behind our back, so re-read the catalogue
    // when one finishes rather than showing counts from before it ran.
    Connections {
        target: JarvosSync

        function onSyncFinished(action: string, ok: bool): void {
            if (ok && action === "restore")
                JarvosSetup.refresh();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large

        spacing: Appearance.spacing.large

        Header {
            Layout.leftMargin: Appearance.padding.large
            Layout.rightMargin: Appearance.padding.large
            Layout.topMargin: Appearance.padding.normal
        }

        ProfileDoors {
            settled: root.settled
            onRestoreRequested: dialog.show("restore")
            onCreateRequested: dialog.show("create")
        }

        StyledRect {
            Layout.fillWidth: true
            visible: JarvosSetup.listError !== ""

            implicitHeight: errorRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Colours.palette.m3errorContainer

            RowLayout {
                id: errorRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Appearance.padding.normal

                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "error"
                    color: Colours.palette.m3onErrorContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: JarvosSetup.listError
                    color: Colours.palette.m3onErrorContainer
                    wrapMode: Text.WordWrap
                }
            }
        }

        StyledFlickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentHeight: cards.height
            flickableDirection: Flickable.VerticalFlick

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flickable
            }

            ColumnLayout {
                id: cards

                width: flickable.width - Appearance.padding.small
                spacing: Appearance.spacing.normal

                Repeater {
                    model: JarvosSetup.modules

                    ModuleCard {
                        required property var modelData

                        module: modelData
                        selected: root.selection[modelData.id] === true
                        onToggled: root.toggle(modelData.id)
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: root.selectedNeedsToolchain

            implicitHeight: toolchainRow.implicitHeight + Appearance.padding.normal * 2
            radius: Appearance.rounding.normal
            color: Colours.palette.m3secondaryContainer

            RowLayout {
                id: toolchainRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Appearance.padding.normal

                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    text: "handyman"
                    color: Colours.palette.m3onSecondaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("A few of these are not in the binary repo, so JarvOS will install the build toolchain (base-devel and yay) first. That happens once, before anything else, and you will see it named as it runs.")
                    color: Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        StatusBanner {}

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Appearance.padding.normal
            spacing: Appearance.spacing.normal

            TextButton {
                type: TextButton.Text
                text: root.anyQueued || JarvosSync.finished ? qsTr("Close") : qsTr("Skip for now")
                onClicked: {
                    JarvosSetup.markDone();
                    root.closeRequested();
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: !JarvosSetup.busy && root.selectedIds.length > 0
                text: qsTr("%1 selected").arg(root.selectedIds.length)
                color: Colours.palette.m3outline
            }

            TextButton {
                type: TextButton.Tonal
                text: qsTr("Refresh")
                enabled: !JarvosSetup.loading
                opacity: enabled ? 1 : 0.5
                onClicked: JarvosSetup.refresh()
            }

            TextButton {
                enabled: !JarvosSetup.busy && !JarvosSync.running && root.selectedIds.length > 0
                opacity: enabled ? 1 : 0.5
                text: JarvosSetup.busy ? qsTr("Installing…") : qsTr("Install")
                onClicked: {
                    JarvosSetup.markDone();
                    JarvosSetup.install(root.selectedIds);
                }
            }
        }
    }

    ProfileDialog {
        id: dialog
    }

    PasswordPrompt {}
}
