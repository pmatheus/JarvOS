import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import "root:/modules/common/functions/color_utils.js" as ColorUtils
import "root:/modules/sidebarRight/calendar/calendar_layout.js" as CalendarLayout
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

Item {
    id: calendarController
    
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    property real widgetWidth: Appearance.sizes.mediaControlsWidth
    property real widgetHeight: Appearance.sizes.mediaControlsHeight * 1.8
    
    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: {
        const layout = CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0);
        // Flatten the 2D array into 1D array for Repeater
        let flatLayout = [];
        for (let i = 0; i < layout.length; i++) {
            for (let j = 0; j < layout[i].length; j++) {
                if (layout[i][j]) {
                    flatLayout.push({
                        day: layout[i][j].day,
                        isToday: layout[i][j].today === 1,
                        isCurrentMonth: layout[i][j].today >= 0
                    });
                }
            }
        }
        return flatLayout;
    }

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
            onWheel: (event) => {
                if (event.angleDelta.y > 0) {
                    monthShift--;
                } else if (event.angleDelta.y < 0) {
                    monthShift++;
                }
            }
        }
        

        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            // Calendar header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: monthTitle.implicitHeight + 8
                    color: monthTitleMouseArea.containsMouse ? Appearance.colors.colLayer2 : "transparent"
                    radius: Appearance.rounding.full
                    
                    StyledText {
                        id: monthTitle
                        anchors.centerIn: parent
                        text: `${monthShift != 0 ? "• " : ""}${viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    MouseArea {
                        id: monthTitleMouseArea
                        anchors.fill: parent
                        onClicked: monthShift = 0
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                    }
                }
            }

            // Days of week header
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        horizontalAlignment: Text.AlignHCenter
                        font.weight: Font.Medium
                    }
                }
            }

            // Calendar grid
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: calendarLayout.length
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        property var dayData: calendarLayout[index]
                        
                        color: dayData.isToday ? 
                            Appearance.colors.colPrimary : 
                            dayData.isCurrentMonth ? 
                                "transparent" : 
                                "transparent"
                        
                        radius: 4
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: dayData.day
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: dayData.isToday ? 
                                Appearance.colors.colOnPrimary :
                                dayData.isCurrentMonth ? 
                                    Appearance.colors.colOnLayer1 : 
                                    Qt.rgba(0.5, 0.5, 0.5, 1.0)
                            font.weight: Font.Normal
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                if (dayData.isCurrentMonth && !dayData.isToday) {
                                    parent.color = Qt.rgba(Appearance.colors.colPrimary.r, 
                                                         Appearance.colors.colPrimary.g, 
                                                         Appearance.colors.colPrimary.b, 0.3)
                                }
                            }
                            onExited: {
                                if (!dayData.isToday) {
                                    parent.color = "transparent"
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}