import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    property QtObject bar: null
    property string moduleName: "jarvos.identity"
    property var settings: ({})
    implicitWidth: bar && bar.vertical ? 26 : 102
    implicitHeight: 26

    IconImage {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 22
        source: Qt.resolvedUrl("mark.svg")
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.bar || !root.bar.vertical
        text: "JarvOS"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: root.bar ? root.bar.barForeground : "#d5e4e4"
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(["jarvos-shell", mouse.button === Qt.RightButton ? "apps" : "menu"])
    }
}
