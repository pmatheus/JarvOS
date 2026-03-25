import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import "../"
import Quickshell.Io
import Quickshell
import QtQuick


QuickToggleButton {
    id: nightLightButton
    property bool enabled: Hyprsunset.active
    toggled: enabled
    buttonIcon: Config.options.light.night.automatic ? "night_sight_auto" : "bedtime"
    onClicked: {
        Hyprsunset.toggle()
    }

    altAction: () => {
        Config.options.light.night.automatic = !Config.options.light.night.automatic
    }

    Component.onCompleted: {
        Hyprsunset.fetchState()
    }
    
    StyledToolTip {
        content: qsTr("Night Light | Right-click to toggle Auto mode")
    }
}
