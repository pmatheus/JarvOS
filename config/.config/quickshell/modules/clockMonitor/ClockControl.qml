import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import "root:/modules/common/functions/color_utils.js" as ColorUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

Item {
    id: clockController

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    property real widgetWidth: Appearance.sizes.mediaControlsWidth * 0.85
    property real widgetHeight: Appearance.sizes.mediaControlsHeight * 0.85

    // High-frequency state
    property string currentHours: "00"
    property string currentMinutes: "00"
    property string currentSeconds: "00"
    property string currentMillis: "000"
    property string currentDate: ""
    property int prevSeconds: -1

    // Background shadow
    StyledRectangularShadow {
        target: backgroundRect
    }

    // Background
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding

        MouseArea {
            anchors.fill: parent
            onPressed: event => event.accepted = true
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 24
            }
            spacing: 16

            // Date with icon
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                MaterialSymbol {
                    text: "calendar_today"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.6
                }

                StyledText {
                    id: dateText
                    text: clockController.currentDate
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.6
                }
            }

            // Main clock — large animated digits
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: mainTimeRow.implicitHeight
                Layout.preferredWidth: mainTimeRow.implicitWidth

                RowLayout {
                    id: mainTimeRow
                    anchors.centerIn: parent
                    spacing: 0

                    MaterialSymbol {
                        text: "schedule"
                        iconSize: Appearance.font.pixelSize.huge * 1.4
                        color: Appearance.colors.colPrimary
                        Layout.rightMargin: 12

                        // Gentle rotation on the clock icon
                        RotationAnimation on rotation {
                            from: 0; to: 360
                            duration: 60000
                            loops: Animation.Infinite
                        }
                    }

                    // Hours
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.8
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        text: clockController.currentHours
                    }

                    // Colon with pulse
                    StyledText {
                        id: mainColon1
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.6
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                        text: ":"

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Minutes
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.8
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        text: clockController.currentMinutes
                    }

                    // Colon with pulse (synced)
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.6
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                        text: ":"

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Seconds
                    StyledText {
                        id: secondsText
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.8
                        font.family: Appearance.font.family.monospace
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        text: clockController.currentSeconds

                        // Brief scale bump when seconds change
                        property real bump: 1.0
                        transform: Scale {
                            origin.x: secondsText.width / 2
                            origin.y: secondsText.height / 2
                            xScale: secondsText.bump
                            yScale: secondsText.bump
                        }
                    }
                }
            }

            // Milliseconds bar — a thin animated progress strip
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: mainTimeRow.implicitWidth * 0.7
                Layout.preferredHeight: 6

                Rectangle {
                    id: msTrack
                    anchors.fill: parent
                    radius: 3
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                }

                Rectangle {
                    id: msFill
                    height: parent.height
                    radius: 3
                    color: Appearance.colors.colPrimary
                    opacity: 0.7
                    width: parent.width * (parseInt(clockController.currentMillis) / 1000)

                    Behavior on width {
                        enabled: parseInt(clockController.currentMillis) > 50 // skip wrap-around jump
                        NumberAnimation {
                            duration: 47
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            // Milliseconds readout
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colOnLayer1
                opacity: 0.4
                text: "." + clockController.currentMillis
            }

            // Uptime
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                MaterialSymbol {
                    text: "timer"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.5
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.5
                    text: "uptime " + DateTime.uptime
                }
            }
        }
    }

    Timer {
        interval: 47
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const h = now.getHours();
            const m = now.getMinutes();
            const s = now.getSeconds();
            const ms = now.getMilliseconds();
            clockController.currentHours = (h < 10 ? "0" : "") + h;
            clockController.currentMinutes = (m < 10 ? "0" : "") + m;
            clockController.currentSeconds = (s < 10 ? "0" : "") + s;
            clockController.currentMillis = (ms < 100 ? "0" : "") + (ms < 10 ? "0" : "") + ms;
            clockController.currentDate = Qt.locale().toString(now, "dddd, MMMM d");

            // Trigger bump animation on second change
            if (s !== clockController.prevSeconds) {
                clockController.prevSeconds = s;
                bumpAnim.restart();
            }
        }
    }

    SequentialAnimation {
        id: bumpAnim
        NumberAnimation {
            target: secondsText; property: "bump"
            to: 1.08; duration: 80
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: secondsText; property: "bump"
            to: 1.0; duration: 160
            easing.type: Easing.InOutQuad
        }
    }
}
