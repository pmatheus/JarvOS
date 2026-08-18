pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// The two continuity doors. Deliberately one slim strip above the module list:
// the modules are the main act, this is the shortcut for someone who already
// has a JarvOS life somewhere else.
StyledRect {
    id: root

    // Nudged forward once the user has actually set this machine up, so it
    // reads as the natural next step rather than a gate on the way in.
    required property bool settled

    signal restoreRequested
    signal createRequested

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainerLow

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.large

        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            MaterialIcon {
                text: "cloud_sync"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("A profile repo makes reinstalling, formatting, or moving to a new machine a non-event.")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Door {
                icon: "settings_backup_restore"
                title: qsTr("Restore my profile")
                subtitle: qsTr("Point at your private repo and this machine becomes that machine.")
                highlighted: !root.settled
                onClicked: root.restoreRequested()
            }

            Door {
                icon: "cloud_upload"
                title: qsTr("Create my profile")
                subtitle: root.settled ? qsTr("Seed a private repo from this machine.") : qsTr("Available once you have picked your modules.")
                highlighted: root.settled
                dimmed: !root.settled
                onClicked: root.createRequested()
            }
        }
    }

    component Door: StyledRect {
        id: door

        required property string icon
        required property string title
        required property string subtitle
        property bool highlighted
        property bool dimmed

        signal clicked

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: doorLayout.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.normal
        color: door.highlighted ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        opacity: door.dimmed ? 0.7 : 1

        StateLayer {
            disabled: JarvosSync.running
            radius: parent.radius

            function onClicked(): void {
                door.clicked();
            }
        }

        RowLayout {
            id: doorLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignTop
                text: door.icon
                color: door.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
                fill: door.highlighted ? 1 : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: door.title
                    color: door.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 500
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: door.subtitle
                    color: door.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
