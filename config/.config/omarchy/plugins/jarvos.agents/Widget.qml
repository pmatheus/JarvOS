import QtQuick
import Quickshell

Item {
    id: root
    property QtObject bar: null
    property string moduleName: "jarvos.agents"
    property var settings: ({})
    implicitWidth: bar && bar.vertical ? 26 : 64
    implicitHeight: 26
    Text {
        anchors.centerIn: parent
        text: root.bar && root.bar.vertical ? "AI" : "Agents"
        font.pixelSize: 12
        color: root.bar ? root.bar.barForeground : "#d5e4e4"
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["jarvos-agent-pick"])
    }
}
