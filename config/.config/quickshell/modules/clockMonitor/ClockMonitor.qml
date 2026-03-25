import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth * 0.8
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight * 0.8

    GlobalShortcut {
        name: "clockMonitorToggle"
        description: qsTr("Toggles clock monitor on press")

        onPressed: {
            clockMonitorLoader.active = !clockMonitorLoader.active
        }
    }

    Loader {
        id: clockMonitorLoader
        active: false

        sourceComponent: PanelWindow {
            id: clockMonitorRoot
            visible: true

            function hide() {
                clockMonitorLoader.active = false
            }

            exclusiveZone: 0
            implicitWidth: clockColumnLayout.implicitWidth
            implicitHeight: clockColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:clockMonitor"

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
                right: true
            }
            mask: Region {
                item: clockColumnLayout
            }

            HyprlandFocusGrab {
                id: grab
                windows: [ clockMonitorRoot ]
                active: clockMonitorLoader.active
                onCleared: () => {
                    if (!active) clockMonitorRoot.hide()
                }
            }

            ColumnLayout {
                id: clockColumnLayout
                anchors.top: parent.top
                anchors.topMargin: -10
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                focus: clockMonitorLoader.active
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        clockMonitorRoot.hide();
                    }
                }

                ClockControl {}
            }
        }
    }

    IpcHandler {
        target: "clockMonitor"

        function toggle(): void {
            clockMonitorLoader.active = !clockMonitorLoader.active;
        }

        function close(): void {
            clockMonitorLoader.active = false;
        }

        function open(): void {
            clockMonitorLoader.active = true;
        }
    }
}