pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shown only when the backend reports that sudo wants a password. The value is
// handed straight to the backend's private FIFO and never stored anywhere.
Item {
    id: root

    function submit(): void {
        JarvosSetup.submitPassword(field.text);
        field.text = "";
    }

    anchors.fill: parent
    visible: opacity > 0
    opacity: JarvosSetup.needsPassword ? 1 : 0
    z: 100

    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => field.forceActiveFocus());
        else
            field.text = "";
    }

    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.6)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    StyledRect {
        anchors.centerIn: parent

        implicitWidth: 420
        implicitHeight: column.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    text: "admin_panel_settings"
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: qsTr("Administrator password")
                        font.pointSize: Appearance.font.size.larger
                        font.weight: 500
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Installing packages needs root. Asked once per install.")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small

                implicitHeight: field.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.normal
                color: Colours.tPalette.m3surfaceContainer
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outline

                StyledTextField {
                    id: field

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal

                    echoMode: TextField.Password
                    placeholderText: qsTr("Password")
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: root.submit()

                    Keys.onEscapePressed: JarvosSetup.submitPassword("")
                }

                Behavior on border.color {
                    CAnim {}
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    type: TextButton.Text
                    text: qsTr("Cancel")
                    onClicked: JarvosSetup.submitPassword("")
                }

                TextButton {
                    text: qsTr("Continue")
                    onClicked: root.submit()
                }
            }
        }
    }

    Behavior on opacity {
        Anim {}
    }
}
