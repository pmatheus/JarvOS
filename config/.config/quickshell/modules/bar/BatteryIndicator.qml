import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100
    readonly property color batteryLowBackground: Appearance.m3colors.darkmode ? Appearance.m3colors.m3error : Appearance.m3colors.m3errorContainer
    readonly property color batteryLowOnBackground: Appearance.m3colors.darkmode ? Appearance.m3colors.m3errorContainer : Appearance.m3colors.m3error

    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: 32

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent


        CircularProgress {
            Layout.alignment: Qt.AlignVCenter
            lineWidth: 2
            value: percentage
            size: 26
            secondaryColor: (isLow && !isCharging) ? batteryLowBackground : Appearance.colors.colSecondaryContainer
            primaryColor: (isLow && !isCharging) ? batteryLowOnBackground : Appearance.m3colors.m3onSecondaryContainer
            fill: (isLow && !isCharging)

            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: isCharging ? "bolt" : "battery_full"
                iconSize: Appearance.font.pixelSize.normal
                color: (isLow && !isCharging) ? batteryLowOnBackground : Appearance.m3colors.m3onSecondaryContainer
            }

        }

    }


}
