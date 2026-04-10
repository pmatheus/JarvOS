pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 - Appearance.spacing.large;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    visible: shouldBeActive
    // Directly track content size — no wrapper animation
    implicitHeight: content.active && content.visible ? content.implicitHeight : 0
    implicitWidth: content.implicitWidth

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            content.active = true;
            content.visible = true;
        } else {
            // Small delay before deactivating so close feels instant
            deactivateTimer.start();
        }
    }

    Timer {
        id: deactivateTimer

        interval: 50
        onTriggered: {
            if (!root.shouldBeActive) {
                content.visible = false;
                content.active = Qt.binding(() => root.shouldBeActive);
            }
        }
    }

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged(): void {
            if (root.shouldBeActive)
                content.active = true;
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        visible: false
        active: false

        sourceComponent: Content {
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }
}
