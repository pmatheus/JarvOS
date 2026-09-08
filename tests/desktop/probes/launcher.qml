import Quickshell
import QtQuick
import qs.modules.launcher
import qs.modules.launcher.services
import qs.components.controls
ShellRoot {
    id: root
    property StyledTextField field: StyledTextField {}
    property PersistentProperties visibility: PersistentProperties {}
    property AppList list: AppList { search: root.field; visibilities: root.visibility }
    Timer { interval: 1000; running: true; onTriggered: root.field.text = ">scheme jarvos" }
    Timer {
        interval: 3500
        running: true
        onTriggered: {
            console.log("LIST_PROBE state=" + root.list.state + " values=" + root.list.model.values.length + " count=" + root.list.count + " schemes=" + Schemes.list.length + " query=" + Schemes.query(">scheme jarvos").length);
            Qt.quit();
        }
    }
}
