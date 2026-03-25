//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import "root:/services/"
import "root:/modules/common/"
import "root:/modules/common/widgets/"

ApplicationWindow {
    id: root
    visible: true
    onClosing: Qt.quit()
    title: "Welcome"

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
    }

    minimumWidth: 400
    minimumHeight: 300
    width: 500
    height: 350
    color: Appearance.m3colors.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: 30
        }
        spacing: 15

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            color: Appearance.colors.colOnLayer0
            text: "Welcome to Hypr-Arch!"
            font.pixelSize: Appearance.font.pixelSize.title
            font.family: Appearance.font.family.title
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding
            
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 20
                }
                spacing: 10

                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colOnLayer0
                    text: "Quick Tips:"
                    font.pixelSize: Appearance.font.pixelSize.large
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    RowLayout {
                        spacing: 3
                        KeyboardKey {
                            key: "Super"
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                        }
                        KeyboardKey {
                            key: "Enter"
                        }
                    }
                    
                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        text: "Open Terminal"
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    RowLayout {
                        spacing: 3
                        KeyboardKey {
                            key: "Super"
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                        }
                        KeyboardKey {
                            key: "I"
                        }
                    }
                    
                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        text: "Open Settings"
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    RowLayout {
                        spacing: 3
                        KeyboardKey {
                            key: "Super"
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                        }
                        KeyboardKey {
                            key: "H"
                        }
                    }
                    
                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        text: "Show Keybinds Cheatsheet"
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    RowLayout {
                        spacing: 3
                        KeyboardKey {
                            key: "Ctrl"
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                        }
                        KeyboardKey {
                            key: "Alt"
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            text: "+"
                        }
                        KeyboardKey {
                            key: "Del"
                        }
                    }
                    
                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        text: "Session Menu"
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }

            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            buttonRadius: Appearance.rounding.small
            implicitWidth: 80
            implicitHeight: 35
            onClicked: root.close()
            
            contentItem: StyledText {
                anchors.centerIn: parent
                text: "Close"
                color: Appearance.colors.colOnSecondaryContainer
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}