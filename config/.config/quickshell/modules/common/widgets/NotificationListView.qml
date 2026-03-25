import "root:/"
import "root:/modules/common/"
import "root:/modules/common/widgets"
import "root:/services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

StyledListView { // Scrollable window
    id: root
    property bool popup: false

    spacing: 3

    model: ScriptModel {
        values: {
            const appNameList = root.popup ? Notifications.popupAppNameList : Notifications.appNameList;
            const groups = root.popup ? Notifications.popupGroupsByAppName : Notifications.groupsByAppName;
            
            // Filter out apps with only empty notifications
            return appNameList.filter(appName => {
                const group = groups[appName];
                if (!group || !group.notifications) return false;
                
                // Check if at least one notification in the group has valid content
                return group.notifications.some(notif => {
                    const hasValidSummary = notif.summary && notif.summary.trim() !== "";
                    const hasValidBody = notif.body && notif.body.trim() !== "";
                    return hasValidSummary || hasValidBody;
                });
            });
        }
    }
    delegate: NotificationGroup {
        required property int index
        required property var modelData
        popup: root.popup
        anchors.left: parent?.left
        anchors.right: parent?.right
        notificationGroup: popup ? 
            Notifications.popupGroupsByAppName[modelData] :
            Notifications.groupsByAppName[modelData]
    }
}