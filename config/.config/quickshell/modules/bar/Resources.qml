// root:/modules/common/Resources.qml
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: 32

    property bool mediaActive: MprisController.activePlayer?.trackTitle?.length > 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.LeftButton) {
                Hyprland.dispatch("global quickshell:resourceMonitorToggle")
            }
        }
    }

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        // CPU: Sempre visível
        Resource {
            iconName: "developer_board"
            percentage: ResourceUsage.cpuUsage
            shown: true
            Layout.leftMargin: shown ? 4 : 0
        }

        // RAM: Sempre visível
        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: true
            Layout.leftMargin: 4
        }

        // Disco: Sempre visível
        Resource {
            iconName: "hard_drive"
            percentage: ResourceUsage.diskUsedPercentage ?? 0
            shown: true
            Layout.leftMargin: shown ? 4 : 0
        }

        // Temperatura
        Resource {
            iconName: "thermostat"
            percentage: (ResourceUsage.cpuTemperature / 100) ?? 0
            shown: !root.mediaActive && percentage >= 0.70
            Layout.leftMargin: shown ? 4 : 0
        }

        // Download Speed
        Resource {
            iconName: "arrow_downward"
            percentage: Math.min(1, (ResourceUsage.netDownloadSpeed / (80 * 1024)))
            shown: !root.mediaActive && percentage >= 0.10
            Layout.leftMargin: shown ? 4 : 0
        }

        // Upload Speed
        Resource {
            iconName: "arrow_upward"
            percentage: Math.min(1, (ResourceUsage.netUploadSpeed / (40 * 1024)))
            shown: !root.mediaActive && percentage >= 0.10
            Layout.leftMargin: shown ? 4 : 0
        }
    }
}