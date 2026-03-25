// Copyright at EOF

import QtQuick 2.11
import QtQuick.Layouts 1.11
import QtQuick.Controls 2.4

RowLayout {

    spacing: root.font.pointSize

    readonly property var suspend: ["dark_mode", config.TranslateSuspend || textConstants.suspend, sddm.canSuspend]
    readonly property var hibernate: ["bedtime", config.TranslateHibernate || textConstants.hibernate, sddm.canHibernate]
    readonly property var reboot: ["restart_alt", config.TranslateReboot || textConstants.reboot, sddm.canReboot]
    readonly property var shutdown: ["power_settings_new", config.TranslateShutdown || textConstants.shutdown, sddm.canPowerOff]

    property Control exposedSession

    Repeater {

        id: systemButtons
        model: [suspend, hibernate, reboot, shutdown]

        RoundButton {
            text: modelData[1]
            font.pointSize: root.font.pointSize * 0.8
            Layout.alignment: Qt.AlignHCenter
            
            // Use Material Design icons instead of SVG files
            contentItem: Column {
                spacing: 4
                Text {
                    text: modelData[0]
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 2 * Math.round((root.font.pointSize * 3) / 2)
                    color: parent.parent.palette.buttonText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: modelData[1]
                    font.pointSize: root.font.pointSize * 0.8
                    color: parent.parent.palette.buttonText
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            visible: config.ForceHideSystemButtons != "true" && modelData[2]
            hoverEnabled: true
            palette.buttonText: config.MainColour
            background: Rectangle {
                height: 2
                color: "transparent"
                width: parent.width
                border.width: parent.activeFocus ? 1 : 0
                border.color: "transparent"
                anchors.top: parent.bottom
            }
            Keys.onReturnPressed: clicked()
            onClicked: {
                parent.forceActiveFocus()
                index == 0 ? sddm.suspend() : index == 1 ? sddm.hibernate() : index == 2 ? sddm.reboot() : sddm.powerOff()
            }
            KeyNavigation.up: exposedSession
            KeyNavigation.left: parent.children[index-1]

            states: [
                State {
                    name: "pressed"
                    when: parent.children[index].down
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: Qt.darker(config.AccentColour, 1.1)
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: Qt.darker(config.AccentColour, 1.1)
                    }
                },
                State {
                    name: "hovered"
                    when: parent.children[index].hovered
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: config.AccentColour
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: config.AccentColour
                    }
                },
                State {
                    name: "focused"
                    when: parent.children[index].activeFocus
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: config.AccentColour
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: config.AccentColour
                    }
                }
            ]

            transitions: [
                Transition {
                    PropertyAnimation {
                        properties: "palette.buttonText, border.color"
                        duration: 150
                    }
                }
            ]
        }
    }
}

// This file is part of SDDM Eucalyptus Drop.
// A theme for the Simple Display Desktop Manager.
//
// Copyright (C) 2018–2020 Marian Arlt
// Copyright (C) 2020-2024 <matt.jolly@footclan.ninja>
//
// SDDM Eucalyptus Drop is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or any later version.
//
// You are required to preserve this and any additional legal notices, either
// contained in this file or in other files that you received along with
// SDDM Eucalyptus Drop that refer to the author(s) in accordance with
// sections §4, §5 and specifically §7b of the GNU General Public License.
//
// SDDM Eucalyptus Drop is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with SDDM Eucalyptus Drop. If not, see <https://www.gnu.org/licenses/>
