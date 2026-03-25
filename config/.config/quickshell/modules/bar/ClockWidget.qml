import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth
    implicitHeight: 32

    // Removed global mouse area to allow specific click areas

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        // Date section - clickable area for calendar
        Item {
            visible: root.showDate
            Layout.fillHeight: true
            implicitWidth: dateRow.implicitWidth
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: (event) => {
                    if (event.button === Qt.LeftButton) {
                        Hyprland.dispatch("global quickshell:calendarMonitorToggle")
                    }
                }
            }
            
            RowLayout {
                id: dateRow
                anchors.centerIn: parent
                spacing: 4
                
                MaterialSymbol {
                    text: "calendar_today"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: Config.options.bar.weather.enable ? Qt.locale().toString(DateTime.clock.date, "ddd dd/MM") : DateTime.date
                }
            }
        }

        StyledText {
            visible: Config.options.bar.weather.enable
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: " "
        }
        
        // Weather section - clickable area for weather popup
        Item {
            visible: Config.options.bar.weather.enable
            Layout.fillHeight: true
            implicitWidth: weatherRow.implicitWidth
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: (event) => {
                    if (event.button === Qt.LeftButton) {
                        Hyprland.dispatch("global quickshell:weatherMonitorToggle")
                    }
                }
            }
            
            RowLayout {
                id: weatherRow
                anchors.centerIn: parent
                spacing: 4
                
                MaterialSymbol {
                    text: Weather.getWeatherIcon(Weather.data.condition)
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    text: Weather.data.temp
                }
            }
        }
        
        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: " "
        }

        // Clock section - clickable area for clock popup
        Item {
            Layout.fillHeight: true
            implicitWidth: clockRow.implicitWidth
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onPressed: (event) => {
                    if (event.button === Qt.LeftButton) {
                        Hyprland.dispatch("global quickshell:clockMonitorToggle")
                    }
                }
            }
            
            RowLayout {
                id: clockRow
                anchors.centerIn: parent
                spacing: 4
                
                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: DateTime.time
                }
            }
        }
        


    }

}
