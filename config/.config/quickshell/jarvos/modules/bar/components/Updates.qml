pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    property var bar: null

    readonly property int padding: Appearance.padding.normal
    readonly property bool isUpdating: UpdateStatus.updating
    readonly property bool isReboot: UpdateStatus.rebootRequired
    readonly property bool isScheduled: UpdateStatus.rebootScheduled
    readonly property bool isRunning: UpdateStatus.running
    readonly property bool hasUpdates: UpdateStatus.total > 0

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: isUpdating
        ? Colours.palette.m3primaryContainer
        : isReboot
            ? Colours.palette.m3errorContainer
            : isScheduled || hasUpdates
                ? Colours.palette.m3tertiaryContainer
                : Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)

    radius: Appearance.rounding.full

    Behavior on color {
        ColorAnimation { duration: 250 }
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: root.isUpdating || root.isRunning
                ? "sync"
                : root.isReboot
                    ? "restart_alt"
                    : root.isScheduled
                        ? "schedule"
                        : "system_update_alt"

            color: root.isUpdating
                ? Colours.palette.m3onPrimaryContainer
                : root.isReboot
                    ? Colours.palette.m3onErrorContainer
                    : root.isScheduled || root.hasUpdates
                        ? Colours.palette.m3onTertiaryContainer
                        : Qt.alpha(Colours.palette.m3secondary, 0.5)

            font.pointSize: Appearance.font.size.normal

            RotationAnimation on rotation {
                running: root.isRunning || root.isUpdating
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1000
            }

            Behavior on color {
                ColorAnimation { duration: 250 }
            }
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            text: root.isUpdating
                ? qsTr("Atualizando...")
                : root.isReboot
                    ? qsTr("Reiniciar")
                    : root.isScheduled
                        ? (UpdateStatus.scheduledRebootTime.length >= 5 ? UpdateStatus.scheduledRebootTime.slice(0, 5) : qsTr("Agendado"))
                        : root.isRunning
                            ? "..."
                            : root.hasUpdates
                                ? `${UpdateStatus.total}`
                                : "0"

            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            font.bold: root.isUpdating || root.isReboot || root.isScheduled || root.hasUpdates

            color: root.isUpdating
                ? Colours.palette.m3onPrimaryContainer
                : root.isReboot
                    ? Colours.palette.m3onErrorContainer
                    : root.isScheduled || root.hasUpdates
                        ? Colours.palette.m3onTertiaryContainer
                        : Qt.alpha(Colours.palette.m3secondary, 0.5)

            Behavior on color {
                ColorAnimation { duration: 250 }
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

            if (popouts.hasCurrent && popouts.currentName === "updates") {
                popouts.hasCurrent = false;
            } else {
                popouts.currentName = "updates";
                popouts.currentCenter = root.mapToItem(root.bar, root.width / 2, 0).x;
                popouts.hasCurrent = true;
            }
        }
    }
}
