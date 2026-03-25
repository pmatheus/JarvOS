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
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    readonly property real osdWidth: Appearance.sizes.osdWidth

    GlobalShortcut {
        name: "resourceMonitorToggle"
        description: qsTr("Toggles resource monitor on press")

        onPressed: {
            resourceMonitorLoader.active = !resourceMonitorLoader.active
        }
    }

    Loader {
        id: resourceMonitorLoader
        active: false

        sourceComponent: PanelWindow {
            id: resourceMonitorRoot
            visible: true

            function hide() {
                resourceMonitorLoader.active = false
            }

            exclusiveZone: 0
            implicitWidth: resourceColumnLayout.implicitWidth
            implicitHeight: resourceColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:resourceMonitor"

            anchors {
                top: !Config.options.bar.bottom
                bottom: Config.options.bar.bottom
                left: true
                right: true
            }
            mask: Region {
                item: resourceColumnLayout
            }

            HyprlandFocusGrab {
                id: grab
                windows: [ resourceMonitorRoot ]
                active: resourceMonitorLoader.active
                onCleared: () => {
                    if (!active) resourceMonitorRoot.hide()
                }
            }

            ColumnLayout {
                id: resourceColumnLayout
                anchors.top: parent.top
                anchors.topMargin: -10
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                focus: resourceMonitorLoader.active
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        resourceMonitorRoot.hide();
                    }
                }

                ResourceControl {}
            }
        }
    }
}