pragma ComponentBehavior: Bound

import qs.components
import qs.components.misc
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    // Set by Bar.qml so the chip can drive the bar popout system.
    property var bar: null

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Appearance.padding.normal

    // Semantic activity colours derived from the matugen palette:
    // red (error) = download, green (success) = upload.
    readonly property color downColour: Colours.palette.m3error
    readonly property color upColour: Colours.palette.m3success

    // Ignore background trickle so the arrows don't flicker when idle.
    readonly property real activeThreshold: 2048 // bytes/s

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Appearance.rounding.full

    // Keep NetworkUsage polling while this widget is alive.
    Ref {
        service: NetworkUsage
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        NetArrow {
            icon: "south"
            activeColour: root.downColour
            active: NetworkUsage.downloadSpeed > root.activeThreshold
        }

        NetArrow {
            icon: "north"
            activeColour: root.upColour
            active: NetworkUsage.uploadSpeed > root.activeThreshold
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
            if (popouts.hasCurrent && popouts.currentName === "networkSpeed") {
                popouts.hasCurrent = false;
            } else {
                popouts.currentName = "networkSpeed";
                popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                popouts.hasCurrent = true;
            }
        }
    }

    // A directional arrow that dims when idle and blips while traffic flows.
    component NetArrow: MaterialIcon {
        id: arrow

        property string icon
        property color activeColour
        property bool active: false
        property real pulse: 1.0

        Layout.alignment: Qt.AlignVCenter
        text: arrow.icon
        font.pointSize: Appearance.font.size.normal
        color: arrow.active ? arrow.activeColour : root.colour
        opacity: arrow.active ? arrow.pulse : 0.3

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }

        // Blip: pulse the opacity while active; the binding above restores the
        // dim resting state as soon as traffic stops.
        SequentialAnimation on pulse {
            running: arrow.active
            loops: Animation.Infinite
            NumberAnimation {
                to: 1.0
                duration: 300
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                to: 0.4
                duration: 300
                easing.type: Easing.InQuad
            }
        }
    }
}
