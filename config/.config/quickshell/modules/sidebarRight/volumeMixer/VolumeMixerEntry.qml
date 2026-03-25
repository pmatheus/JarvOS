import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Item {
    id: root
    required property PwNode node;
	PwObjectTracker { objects: [ node ] }

    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 5

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                text: {
                    // application.name -> description -> name
                    const app = root.node.properties["application.name"] ?? (root.node.description != "" ? root.node.description : root.node.name);
                    const media = root.node.properties["media.name"];
                    return media != undefined ? `${app} • ${media}` : app;
                }
            }

            RowLayout {
                spacing: 5
                Image {
                    property real size: 16
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    visible: source != ""
                    sourceSize.width: size
                    sourceSize.height: size
                    source: {
                        let icon;
                        icon = AppSearch.guessIcon(root.node.properties["application.icon-name"]);
                        if (AppSearch.iconExists(icon)) return Quickshell.iconPath(icon, "image-missing");
                        icon = AppSearch.guessIcon(root.node.properties["node.name"]);
                        return Quickshell.iconPath(icon, "image-missing");
                    }
                }
                
                StyledSlider {
                    id: slider
                    Layout.fillWidth: true
                    enabled: !root.node.audio.muted
                    opacity: root.node.audio.muted ? 0.5 : 1.0
                    value: root.node.audio.volume
                    onValueChanged: root.node.audio.volume = value
                    
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
                
                RippleButton {
                    id: muteButton
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: 14
                    
                    onClicked: {
                        root.node.audio.muted = !root.node.audio.muted
                    }
                    
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.node.audio.muted ? "volume_off" : "volume_up"
                        iconSize: 24
                        color: root.node.audio.muted ? Appearance.colors.colOnLayer2Disabled : Appearance.colors.colOnLayer2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                    
                    StyledToolTip {
                        content: root.node.audio.muted ? qsTr("Unmute") : qsTr("Mute")
                    }
                }
            }
        }
    }
}