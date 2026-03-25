// Copyright info at EOF

import QtQuick 2.11
import QtQuick.Controls 2.4
import Qt5Compat.GraphicalEffects

Item {
    id: sessionButton
    height: root.font.pointSize
    width: parent.width / 2
    anchors.horizontalCenter: parent.horizontalCenter

    property var selectedSession: selectSession.currentIndex
    property string textConstantSession
    property int loginButtonWidth
    property Control exposeSession: selectSession

    ComboBox {
        id: selectSession

        hoverEnabled: true
        anchors.horizontalCenter: parent.horizontalCenter
        Keys.onPressed: {
            if (event.key == Qt.Key_Up && loginButton.state != "enabled" && !popup.opened)
                revealSecret.focus = true,
                revealSecret.state = "focused",
                currentIndex = currentIndex + 1;
            if (event.key == Qt.Key_Up && loginButton.state == "enabled" && !popup.opened)
                loginButton.focus = true,
                loginButton.state = "focused",
                currentIndex = currentIndex + 1;
            if (event.key == Qt.Key_Down && !popup.opened)
                systemButtons.children[0].focus = true,
                systemButtons.children[0].state = "focused",
                currentIndex = currentIndex - 1;
            if ((event.key == Qt.Key_Left || event.key == Qt.Key_Right) && !popup.opened)
                popup.open();
        }

        model: sessionModel
        currentIndex: model.lastIndex
        textRole: "name"

        delegate: ItemDelegate {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            contentItem: Text {
                text: model.name
                font.pointSize: root.font.pointSize * 0.8
                color: selectSession.highlightedIndex === index ? 
                    (config.OverrideLoginButtonTextColour != "" ? config.OverrideLoginButtonTextColour : "white") : 
                    config.MainColour
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            highlighted: parent.highlightedIndex === index
            background: Rectangle {
                color: selectSession.highlightedIndex === index ? config.AccentColour : "transparent"
            }
        }

        indicator {
            visible: false
        }

        contentItem: Row {
            id: displayedItem
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: "desktop_windows"
                font.family: "Material Symbols Outlined"
                font.pixelSize: root.font.pointSize * 0.9
                color: config.MainColour
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: (config.TranslateSession || (textConstantSession + ":"))
                color: config.MainColour
                verticalAlignment: Text.AlignVCenter
                font.pointSize: root.font.pointSize * 0.8
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: selectSession.currentText
                color: config.MainColour
                verticalAlignment: Text.AlignVCenter
                font.pointSize: root.font.pointSize * 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Keys.onReleased: selectSession.popup.open()
        }

        background: Rectangle {
            color: "transparent"
            border.width: parent.visualFocus ? 1 : 0
            border.color: "transparent"
            height: parent.visualFocus ? 2 : 0
            width: displayedItem.implicitWidth
            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        }

        popup: Popup {
            id: popupHandler
            y: parent.height - 1
            x: -(loginButtonWidth - displayedItem.width) / 2  // Center the popup
            width: loginButtonWidth  // Same width as login button
            implicitHeight: contentItem.implicitHeight
            padding: 10

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight + 20
                model: selectSession.popup.visible ? selectSession.delegateModel : null
                currentIndex: selectSession.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }

            background: Rectangle {
                radius: config.RoundCorners / 2
                color: config.BackgroundColour
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 20 * config.InterfaceShadowSize
                    samples: 41 * config.InterfaceShadowSize
                    cached: true
                    color: Qt.hsla(0,0,0,config.InterfaceShadowOpacity)
                }
            }

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1 }
            }
        }

        states: [
            State {
                name: "pressed"
                when: selectSession.down
                PropertyChanges {
                    target: displayedItem
                    color: Qt.darker(config.AccentColour, 1.1)
                }
                PropertyChanges {
                    target: selectSession.background
                    border.color: Qt.darker(config.AccentColour, 1.1)
                }
            },
            State {
                name: "hovered"
                when: selectSession.hovered
                PropertyChanges {
                    target: displayedItem
                    color: config.AccentColour
                }
                PropertyChanges {
                    target: selectSession.background
                    border.color: config.AccentColour
                }
            },
            State {
                name: "focused"
                when: selectSession.visualFocus
                PropertyChanges {
                    target: displayedItem
                    color: config.AccentColour
                }
                PropertyChanges {
                    target: selectSession.background
                    border.color: config.AccentColour
                }
            }
        ]

        transitions: [
            Transition {
                PropertyAnimation {
                    properties: "color, border.color"
                    duration: 150
                }
            }
        ]

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
