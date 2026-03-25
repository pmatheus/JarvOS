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

    property real widgetWidth: Appearance.sizes.mediaControlsWidth * 0.8
    property real widgetHeight: Appearance.sizes.mediaControlsHeight * 0.8

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
                margins: 20
            }
            spacing: 15

            // Data com ícone
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                
                MaterialSymbol {
                    text: "calendar_today"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
                
                StyledText {
                    id: dateText
                    text: Qt.locale().toString(new Date(), "dddd, MMMM d")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
            }
            
            // Relógio principal com ícone
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                
                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }
                
                StyledText {
                    id: timeText
                    text: {
                        const format = Config.options?.time?.format ?? "hh:mm";
                        let withSeconds;
                        if (format.includes(" AP")) {
                            withSeconds = format.replace(" AP", ":ss AP");
                        } else if (format.includes(" ap")) {
                            withSeconds = format.replace(" ap", ":ss ap");
                        } else {
                            withSeconds = format + ":ss";
                        }
                        return Qt.locale().toString(new Date(), withSeconds);
                    }
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.2
                    //font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }
    
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const format = Config.options?.time?.format ?? "hh:mm";
            let withSeconds;
            if (format.includes(" AP")) {
                withSeconds = format.replace(" AP", ":ss AP");
            } else if (format.includes(" ap")) {
                withSeconds = format.replace(" ap", ":ss ap");
            } else {
                withSeconds = format + ":ss";
            }
            timeText.text = Qt.locale().toString(now, withSeconds);
            dateText.text = Qt.locale().toString(now, "dddd, MMMM d");
        }
    }
}