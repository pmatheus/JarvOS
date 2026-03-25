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
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight * 1.2

    GlobalShortcut {
        name: "weatherMonitorToggle"
        description: qsTr("Toggles weather monitor on press")

        onPressed: {
            weatherMonitorLoader.active = !weatherMonitorLoader.active
        }
    }

    Loader {
        id: weatherMonitorLoader
        active: false

        sourceComponent: PanelWindow {
            id: weatherMonitorRoot
            visible: true

            function hide() {
                weatherMonitorLoader.active = false
            }

            exclusiveZone: 0
            implicitWidth: weatherColumnLayout.implicitWidth
            implicitHeight: weatherColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:weatherMonitor"

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
                right: true
            }
            mask: Region {
                item: weatherColumnLayout
            }

            HyprlandFocusGrab {
                id: grab
                windows: [ weatherMonitorRoot ]
                active: weatherMonitorLoader.active
                onCleared: () => {
                    if (!active) weatherMonitorRoot.hide()
                }
            }

            ColumnLayout {
                id: weatherColumnLayout
                anchors.top: parent.top
                anchors.topMargin: -10
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                focus: weatherMonitorLoader.active
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        weatherMonitorRoot.hide();
                    }
                }

                WeatherControl {}
            }
        }
    }

    IpcHandler {
        target: "weatherMonitor"

        function toggle(): void {
            weatherMonitorLoader.active = !weatherMonitorLoader.active;
        }

        function close(): void {
            weatherMonitorLoader.active = false;
        }

        function open(): void {
            weatherMonitorLoader.active = true;
        }
    }
}