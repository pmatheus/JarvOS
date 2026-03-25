import "root:/"
import "root:/services/"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/common/functions/color_utils.js" as ColorUtils
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    required property var bar
    property bool borderless: Config.options.bar.borderless
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / Config.options.bar.workspaces.shown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 4
    property int workspaceButtonWidth: 26
    property int workspaceMinWidth: 26
    property int workspaceMaxWidth: 80
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property real iconSpacing: 2
    property int workspaceIndexInGroup: (monitor.activeWorkspace?.id - 1) % Config.options.bar.workspaces.shown

    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: Config.options.bar.workspaces.shown }, (_, i) => {
            return Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * Config.options.bar.workspaces.shown + i + 1);
        })
    }

    // Initialize workspaceOccupied when the component is created
    Component.onCompleted: updateWorkspaceOccupied()

    // Listen for changes in Hyprland.workspaces.values
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateWorkspaceOccupied();
        }
    }

    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    // Scroll to switch workspaces
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: (event) => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            } 
        }
    }

    // Workspaces - background
    RowLayout {
        id: rowLayout
        z: 1

        spacing: 0
        anchors.fill: parent
        implicitHeight: Appearance.sizes.barHeight

        Repeater {
            model: Config.options.bar.workspaces.shown

            Rectangle {
                z: 1
                property var workspaceApps: {
                    const workspaceValue = workspaceGroup * Config.options.bar.workspaces.shown + index + 1
                    const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceValue)
                    const uniqueApps = []
                    const seenClasses = new Set()
                    
                    for (const window of windowsInThisWorkspace) {
                        if (window.class && !seenClasses.has(window.class)) {
                            seenClasses.add(window.class)
                            uniqueApps.push(window.class)
                        }
                    }
                    return uniqueApps
                }
                property int calculatedWidth: Math.max(workspaceMinWidth,
                    workspaceApps.length > 0 ? workspaceApps.length * (workspaceIconSize + iconSpacing) - iconSpacing + 6 : workspaceMinWidth)
                
                implicitWidth: calculatedWidth
                implicitHeight: workspaceButtonWidth
                radius: Appearance.rounding.full
                property var leftOccupied: (workspaceOccupied[index-1] && !(!activeWindow?.activated && monitor.activeWorkspace?.id === index))
                property var rightOccupied: (workspaceOccupied[index+1] && !(!activeWindow?.activated && monitor.activeWorkspace?.id === index+2))
                property var radiusLeft: leftOccupied ? 0 : Appearance.rounding.full
                property var radiusRight: rightOccupied ? 0 : Appearance.rounding.full
                
                Behavior on calculatedWidth {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                topLeftRadius: radiusLeft
                bottomLeftRadius: radiusLeft
                topRightRadius: radiusRight
                bottomRightRadius: radiusRight
                
                color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                opacity: (workspaceOccupied[index] && !(!activeWindow?.activated && monitor.activeWorkspace?.id === index+1)) ? 1 : 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on radiusLeft {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Behavior on radiusRight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

            }

        }

    }

    // Active workspace
    Rectangle {
        z: 2
        // Make active ws indicator, which has a brighter color, smaller to look like it is of the same size as ws occupied highlight
        property real activeWorkspaceMargin: 2
        implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        anchors.verticalCenter: parent.verticalCenter

        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup
        
        // Calculate x position based on cumulative widths of previous workspaces
        property real calculatedX: {
            let xPos = activeWorkspaceMargin
            const buttons = rowLayoutNumbers.children
            for (let i = 0; i < Math.min(idx1, idx2); i++) {
                if (buttons[i] && buttons[i].calculatedWidth !== undefined) {
                    xPos += buttons[i].calculatedWidth
                }
            }
            return xPos
        }
        
        // Calculate width based on active workspace button width
        property real calculatedWidth: {
            const buttons = rowLayoutNumbers.children
            const activeIndex = Math.min(idx1, idx2)
            if (buttons[activeIndex] && buttons[activeIndex].calculatedWidth !== undefined) {
                return buttons[activeIndex].calculatedWidth - activeWorkspaceMargin * 2
            }
            return workspaceButtonWidth - activeWorkspaceMargin * 2
        }
        
        x: calculatedX
        implicitWidth: calculatedWidth

        Behavior on activeWorkspaceMargin {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on calculatedX { // Leading anim
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutSine
            }
        }
        Behavior on calculatedWidth { // Following anim
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx1 { // Leading anim
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 { // Following anim
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutSine
            }
        }
    }

    // Workspaces - numbers
    RowLayout {
        id: rowLayoutNumbers
        z: 3

        spacing: 0
        anchors.fill: parent
        implicitHeight: Appearance.sizes.barHeight

        Repeater {
            model: Config.options.bar.workspaces.shown

            Button {
                id: button
                property int workspaceValue: workspaceGroup * Config.options.bar.workspaces.shown + index + 1
                property var workspaceApps: {
                    const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceValue)
                    const uniqueApps = []
                    const seenClasses = new Set()
                    
                    for (const window of windowsInThisWorkspace) {
                        if (window.class && !seenClasses.has(window.class)) {
                            seenClasses.add(window.class)
                            uniqueApps.push(window.class)
                        }
                    }
                    return uniqueApps
                }
                property int calculatedWidth: Math.max(workspaceMinWidth,
                    workspaceApps.length > 0 ? workspaceApps.length * (workspaceIconSize + iconSpacing) - iconSpacing + 6 : workspaceMinWidth)
                
                Layout.fillHeight: true
                onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                width: calculatedWidth
                
                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: button.calculatedWidth
                    implicitHeight: workspaceButtonWidth
                    property var biggestWindow: {
                        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == button.workspaceValue)
                        return windowsInThisWorkspace.reduce((maxWin, win) => {
                            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0)
                            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0)
                            return winArea > maxArea ? win : maxWin
                        }, null)
                    }
                    property var mainAppIconSource: Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.class), "image-missing")

                    StyledText { // Workspace number text
                        opacity: GlobalStates.workspaceShowNumbers
                            || ((Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !workspaceButtonBackground.biggestWindow || GlobalStates.workspaceShowNumbers))
                            || (GlobalStates.workspaceShowNumbers && !Config.options?.bar.workspaces.showAppIcons)
                            )  ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                        text: `${button.workspaceValue}`
                        elide: Text.ElideRight
                        color: (monitor.activeWorkspace?.id == button.workspaceValue) ? 
                            Appearance.m3colors.m3onPrimary : 
                            (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : 
                                Appearance.colors.colOnLayer1Inactive)

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    Rectangle { // Dot instead of ws number
                        opacity: (Config.options?.bar.workspaces.alwaysShowNumbers
                            || GlobalStates.workspaceShowNumbers
                            || (Config.options?.bar.workspaces.showAppIcons && workspaceButtonBackground.biggestWindow)
                            ) ? 0 : 1
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.18
                        height: width
                        radius: width / 2
                        color: (monitor.activeWorkspace?.id == button.workspaceValue) ? 
                            Appearance.m3colors.m3onPrimary : 
                            (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : 
                                Appearance.colors.colOnLayer1Inactive)

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    Row { // Multiple app icons
                        anchors.centerIn: parent
                        spacing: iconSpacing
                        opacity: !Config.options?.bar.workspaces.showAppIcons ? 0 :
                            (button.workspaceApps.length > 0 && !GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? 
                            1 : button.workspaceApps.length > 0 ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0

                        Repeater {
                            model: button.workspaceApps
                            
                            IconImage {
                                property string appClass: modelData
                                source: Quickshell.iconPath(AppSearch.guessIcon(appClass), "image-missing")
                                implicitSize: (!GlobalStates.workspaceShowNumbers && Config.options?.bar.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                                Behavior on implicitSize {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                            }
                        }

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                }
                

            }

        }

    }

}
