import "root:/modules/common"
import "root:/modules/common/widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// TODO: More fancy animation
Item {
    id: root

    required property var bar

    height: parent.height
    implicitWidth: rowLayout.implicitWidth
    Layout.leftMargin: Appearance.rounding.screenRounding

    RowLayout {
        id: rowLayout
        visible: true

        anchors.fill: parent
        spacing: 15

        Repeater {
            model: SystemTray.items

            SysTrayItem {
                required property SystemTrayItem modelData

                bar: root.bar
                item: modelData
                visible: !Config.options.bar.tray.blacklistedApps.includes(modelData.id)
                
                // Debug: mostra o ID no console
                Component.onCompleted: console.log("SystemTray item ID:", modelData.id)
            }

        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colSubtext
            text: "•"
            visible: {
                var visibleItems = 0;
                for (var i = 0; i < SystemTray.items.values.length; i++) {
                    if (!Config.options.bar.tray.blacklistedApps.includes(SystemTray.items.values[i].id)) {
                        visibleItems++;
                    }
                }
                return visibleItems > 0;
            }
        }

    }

}
