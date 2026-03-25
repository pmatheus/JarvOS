import "root:/"
import "root:/services"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/common/functions/string_utils.js" as StringUtils
import "root:/modules/common/functions/file_utils.js" as FileUtils
import "./quickToggles/"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 15
    property string settingsQmlPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/settings.qml`)

    PanelWindow {
        id: sidebarRoot
        visible: GlobalStates.sidebarRightOpen

        function hide() {
            GlobalStates.sidebarRightOpen = false
        }

        exclusiveZone: 0
        width: sidebarWidth
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
        // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [ sidebarRoot ]
            active: GlobalStates.sidebarRightOpen
            onCleared: () => {
                if (!active) sidebarRoot.hide()
            }
        }

        Loader {
            id: sidebarContentLoader
            active: GlobalStates.sidebarRightOpen
            clip: true
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                left: parent.left
                topMargin: Appearance.sizes.hyprlandGapsOut
                rightMargin: Appearance.sizes.hyprlandGapsOut
                bottomMargin: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }
            // Remove explicit width/height to allow anchors to control size

            focus: GlobalStates.sidebarRightOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    sidebarRoot.hide();
                }
            }

            sourceComponent: Item {
                implicitHeight: sidebarRightBackground.implicitHeight
                implicitWidth: sidebarRightBackground.implicitWidth

                StyledRectangularShadow {
                    target: sidebarRightBackground
                }
                Rectangle {
                    id: sidebarRightBackground

                    anchors.fill: parent
                    clip: true
                    implicitHeight: parent.height
                    implicitWidth: parent.width
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                    ColumnLayout {
                        spacing: sidebarPadding
                        anchors.fill: parent
                        anchors.margins: sidebarPadding

                        RowLayout {
                            Layout.fillHeight: false
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.topMargin: 5
                            Layout.bottomMargin: 0

                            Item {
                                implicitWidth: distroIcon.width
                                implicitHeight: distroIcon.height
                                CustomIcon {
                                    id: distroIcon
                                    width: 25
                                    height: 25
                                    source: SystemInfo.distroIcon
                                }
                                ColorOverlay {
                                    anchors.fill: distroIcon
                                    source: distroIcon
                                    color: Appearance.colors.colOnLayer0
                                }
                            }

                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer0
                                text: StringUtils.format(qsTr("Uptime: {0}"), DateTime.uptime)
                                textFormat: Text.MarkdownText
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            ButtonGroup {
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "restart_alt"
                                    onClicked: {
                                        Hyprland.dispatch("reload")
                                        Quickshell.reload(true)
                                    }
                                    StyledToolTip {
                                        content: qsTr("Reload Hyprland & Quickshell")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "flare"
                                    onClicked: {
                                        Quickshell.execDetached(["kitty", "-e", "fish", "-c", "source ~/.config/quickshell/scripts/housekeeping.fish; read -P 'Press any key to continue...'"])
                                        Hyprland.dispatch("global quickshell:sidebarRightClose")
                                    }
                                    StyledToolTip {
                                        content: qsTr("Update & Housekeeping")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "settings"
                                    onClicked: {
                                        Hyprland.dispatch("global quickshell:sidebarRightClose")
                                        Quickshell.execDetached(["qs", "-p", root.settingsQmlPath])
                                    }
                                    StyledToolTip {
                                        content: qsTr("Settings")
                                    }
                                }
                                QuickToggleButton {
                                    toggled: false
                                    buttonIcon: "power_settings_new"
                                    onClicked: {
                                        Hyprland.dispatch("global quickshell:sessionOpen")
                                    }
                                    StyledToolTip {
                                        content: qsTr("Session")
                                    }
                                }
                            }
                        }

                        ButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 5
                            padding: 5
                            color: Appearance.colors.colLayer1

                            NetworkToggle {}
                            BluetoothToggle {}
                            NightLight {}
                            GameMode {}
                            IdleInhibitor {}
                        }

                        // System volume control
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            Layout.rightMargin: 10
                            spacing: 8
                            
                            RippleButton {
                                id: systemVolumeIconButton
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                buttonRadius: 14
                                
                                onClicked: {
                                    if (Audio.sink?.audio) {
                                        Audio.sink.audio.muted = !Audio.sink.audio.muted
                                    }
                                }
                                
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: (Audio.sink?.audio.muted ?? true) ? "volume_off" : "volume_up"
                                    iconSize: Appearance.font.pixelSize.large
                                    color: (Audio.sink?.audio.muted ?? true) ? Appearance.colors.colOnLayer1Inactive : Appearance.colors.colOnLayer1
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    Behavior on color {
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }
                                
                                StyledToolTip {
                                    content: (Audio.sink?.audio.muted ?? true) ? qsTr("Unmute") : qsTr("Mute")
                                }
                            }
                            
                            StyledSlider {
                                id: systemVolumeSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 12
                                
                                // Custom properties to make it thinner
                                scale: 0.4
                                trackHeight: 6
                                handleHeight: 16
                                handleWidth: 3
                                backgroundDotSize: 2
                                backgroundDotMargins: 2
                                
                                enabled: !(Audio.sink?.audio.muted ?? true)
                                opacity: (Audio.sink?.audio.muted ?? true) ? 0.5 : 1.0
                                value: Audio.sink?.audio.volume ?? 0
                                onValueChanged: {
                                    if (Audio.sink?.audio) {
                                        Audio.sink.audio.volume = value
                                    }
                                }
                                
                                Behavior on opacity {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }
                            }
                            
                            RippleButton {
                                id: microphoneMuteButton
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                buttonRadius: 12
                                
                                onClicked: {
                                    if (Audio.source?.audio) {
                                        Audio.source.audio.muted = !Audio.source.audio.muted
                                    }
                                }
                                
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: (Audio.source?.audio.muted ?? true) ? "mic_off" : "mic"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: (Audio.source?.audio.muted ?? true) ? Appearance.colors.colOnLayer1Inactive : Appearance.colors.colOnLayer1
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    Behavior on color {
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }
                                
                                StyledToolTip {
                                    content: (Audio.source?.audio.muted ?? true) ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                                }
                            }
                        }

                        // Center widget group
                        CenterWidgetGroup {
                            focus: sidebarRoot.visible
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                        }

                        BottomWidgetGroup {
                            Layout.fillHeight: false
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                        }
                    }
                }
            }
        }


    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            if(GlobalStates.sidebarRightOpen) Notifications.timeoutAll();
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: qsTr("Toggles right sidebar on press")

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            if(GlobalStates.sidebarRightOpen) Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: qsTr("Opens right sidebar on press")

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
            Notifications.timeoutAll();
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: qsTr("Closes right sidebar on press")

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }

}
