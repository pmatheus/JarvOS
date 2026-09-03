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

    property var bar: null

    property var sessions: []
    readonly property int sessionCount: sessions.length
    readonly property bool hasSessions: sessionCount > 0

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Appearance.rounding.full

    Process {
        id: monitorProc
        command: ["jarvos-agent-monitor"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const trimmed = data.trim();
                    if (trimmed.length > 0) {
                        root.sessions = JSON.parse(trimmed);
                    }
                } catch (e) {
                    // Ignore transient parse error
                }
            }
        }
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "neurology"
            color: root.hasSessions ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.hasSessions ? `${root.sessionCount} AI` : "0 AI"
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            font.bold: true
            color: root.hasSessions ? Colours.palette.m3primary : Qt.alpha(root.colour, 0.4)

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
            if (popouts.hasCurrent && popouts.currentName === "agents") {
                popouts.hasCurrent = false;
            } else {
                popouts.currentName = "agents";
                popouts.currentCenter = root.mapToItem(root.bar, root.width / 2, 0).x;
                popouts.hasCurrent = true;
            }
        }
    }
}
