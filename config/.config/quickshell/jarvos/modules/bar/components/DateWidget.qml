pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities

    readonly property color colour: Colours.palette.m3primary
    readonly property int padding: Appearance.padding.normal

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Config.bar.sizes.innerWidth

    property string dateEnText: ""
    property string dateCnText: ""

    function updateDate(): void {
        const now = new Date();
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        dateEnText = `${weekdays[now.getDay()]}  ${now.getDate()} ${months[now.getMonth()]} ${now.getFullYear()}`;

        const cnMonths = ["\u4E00\u6708", "\u4E8C\u6708", "\u4E09\u6708", "\u56DB\u6708",
                          "\u4E94\u6708", "\u516D\u6708", "\u4E03\u6708", "\u516B\u6708",
                          "\u4E5D\u6708", "\u5341\u6708", "\u5341\u4E00\u6708", "\u5341\u4E8C\u6708"];
        const cnDayUnits = ["\u65E5", "\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D", "\u4E03", "\u516B", "\u4E5D"];
        const d = now.getDate();
        let cnDay;
        if (d <= 10)
            cnDay = "\u521D" + cnDayUnits[d];
        else if (d < 20)
            cnDay = "\u5341" + cnDayUnits[d % 10];
        else if (d === 20)
            cnDay = "\u4E8C\u5341";
        else if (d < 30)
            cnDay = "\u5EFF" + cnDayUnits[d % 10];
        else if (d === 30)
            cnDay = "\u4E09\u5341";
        else
            cnDay = "\u4E09\u5341\u4E00";

        dateCnText = cnMonths[now.getMonth()] + cnDay;
    }

    Component.onCompleted: updateDate()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.updateDate()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.visibilities.dashboard = !root.visibilities.dashboard;
        }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "calendar_today"
            color: root.colour
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateEnText
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.sans
            color: root.colour
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.5
            color: root.colour
            opacity: 0.2
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dateCnText
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.sans
            color: root.colour
            opacity: 0.7
        }
    }
}
