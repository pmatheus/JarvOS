import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    radius: Appearance.rounding.small
    color: "transparent"

    property var resourceItems: [
        {
            "name": qsTr("Processor"),
            "icon": "developer_board",
            "value": Math.round(ResourceUsage.cpuUsage * 100),
            "unit": "%",
            "description": qsTr("CPU usage")
        },
        {
            "name": qsTr("Memory"),
            "icon": "memory",
            "value": Math.round(ResourceUsage.memoryUsedPercentage * 100),
            "unit": "%",
            "description": qsTr("RAM usage")
        },
        {
            "name": qsTr("Storage"),
            "icon": "hard_drive",
            "value": Math.round(ResourceUsage.diskUsedPercentage * 100),
            "unit": "%",
            "description": qsTr("Disk usage")
        },
        {
            "name": qsTr("Temperature"),
            "icon": "thermostat",
            "value": Math.round(ResourceUsage.cpuTemperature),
            "unit": "°C",
            "description": qsTr("CPU temperature")
        },
        {
            "name": qsTr("Download"),
            "icon": "arrow_downward",
            "value": (ResourceUsage.netDownloadSpeed ?? 0).toFixed(1),
            "unit": " KB/s",
            "description": qsTr("Network download speed")
        },
        {
            "name": qsTr("Upload"),
            "icon": "arrow_upward",
            "value": (ResourceUsage.netUploadSpeed ?? 0).toFixed(1),
            "unit": " KB/s",
            "description": qsTr("Network upload speed")
        }
    ]

    StyledListView {
        id: listView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 2
        anchors.bottomMargin: 10

        model: root.resourceItems
        spacing: 2

        delegate: Rectangle {
            width: listView.width
            height: 60
            color: "transparent"
            radius: Appearance.rounding.small

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                MaterialSymbol {
                    text: modelData.icon
                    iconSize: 20
                    color: Appearance.m3colors.m3primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        
                        StyledText {
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: modelData.value + modelData.unit
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    StyledText {
                        text: modelData.description
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3outline
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}