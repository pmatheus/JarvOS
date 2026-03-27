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

    // High-frequency timer for seconds + milliseconds
    property string currentTime: ""
    property string currentSeconds: "00"
    property string currentMillis: "000"

    Timer {
        id: clockTimer
        interval: 47 // ~21fps — smooth enough for ms display, light on CPU
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const format = Config.options?.time?.format ?? "hh:mm";
            root.currentTime = Qt.locale().toString(now, format);
            const s = now.getSeconds();
            root.currentSeconds = (s < 10 ? "0" : "") + s;
            const ms = now.getMilliseconds();
            root.currentMillis = (ms < 100 ? "0" : "") + (ms < 10 ? "0" : "") + ms;
        }
    }

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

        // Clock section - horizontal with seconds and milliseconds
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
                spacing: 2

                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                // Main time (hh:mm)
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnLayer1
                    text: root.currentTime

                    Behavior on text {
                        enabled: false
                    }
                }

                // Colon separator with pulse animation
                StyledText {
                    id: colonSep
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnLayer1
                    text: ":"
                    opacity: 1.0

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                    }
                }

                // Seconds
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnLayer1
                    text: root.currentSeconds
                    opacity: 0.85

                    Behavior on text {
                        enabled: false
                    }
                }

                // Dot separator
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnLayer1
                    text: "."
                    opacity: 0.5
                }

                // Milliseconds with subtle fade
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colOnLayer1
                    text: root.currentMillis
                    opacity: 0.45
                }
            }
        }
    }
}
