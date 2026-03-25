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
    property bool showDeviceSelector: false
    property bool deviceSelectorInput
    property int dialogMargins: 16
    property PwNode selectedDevice
    readonly property list<PwNode> appPwNodes: Pipewire.nodes.values.filter((node) => {
        // return node.type == "21" // Alternative, not as clean
        return node.isSink && node.isStream
    })

    function showDeviceSelectorDialog(input: bool) {
        root.selectedDevice = null
        root.showDeviceSelector = true
        root.deviceSelectorInput = input
    }

    Keys.onPressed: (event) => {
        // Close dialog on pressing Esc if open
        if (event.key === Qt.Key_Escape && root.showDeviceSelector) {
            root.showDeviceSelector = false
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Flickable {
                id: flickable
                anchors.fill: parent
                contentHeight: volumeMixerColumnLayout.height

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: flickable.width
                        height: flickable.height
                        radius: Appearance.rounding.normal
                    }
                }

                ColumnLayout {
                    id: volumeMixerColumnLayout
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 5

                    Repeater {
                        model: root.appPwNodes

                        VolumeMixerEntry {
                            Layout.fillWidth: true
                            required property var modelData
                            node: modelData
                        }
                    }
                }
            }

            // Placeholder when list is empty
            Item {
                anchors.fill: flickable

                visible: opacity > 0
                opacity: (root.appPwNodes.length === 0) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.menuDecel.duration
                        easing.type: Appearance.animation.menuDecel.type
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        iconSize: 55
                        color: Appearance.m3colors.m3outline
                        text: "brand_awareness"
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3outline
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No audio source")
                    }
                }
            }
        }
        // Device selector
        ButtonGroup {
            id: deviceSelectorRowLayout
            Layout.fillWidth: true
            Layout.fillHeight: false
            AudioDeviceSelectorButton {
                Layout.fillWidth: true
                input: false
                onClicked: root.showDeviceSelectorDialog(input)
            }
            AudioDeviceSelectorButton {
                Layout.fillWidth: true
                input: true
                onClicked: root.showDeviceSelectorDialog(input)
            }
        }
    }

    // Device selector dialog
    Item {
        anchors.fill: parent
        z: 9999

        visible: root.showDeviceSelector

        Rectangle { // Scrim
            id: scrimOverlay
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer0
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle { // The dialog
            id: dialog
            color: Appearance.colors.colSurfaceContainerHigh
            radius: Appearance.rounding.normal
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 30
            implicitHeight: dialogColumnLayout.implicitHeight
            
            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    id: dialogTitle
                    Layout.topMargin: dialogMargins
                    Layout.leftMargin: dialogMargins
                    Layout.rightMargin: dialogMargins
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: `Select ${root.deviceSelectorInput ? "input" : "output"} device`
                }

                Rectangle {
                    color: Appearance.m3colors.m3outline
                    implicitHeight: 1
                    Layout.fillWidth: true
                    Layout.leftMargin: dialogMargins
                    Layout.rightMargin: dialogMargins
                }

                Flickable {
                    id: dialogFlickable
                    Layout.fillWidth: true
                    clip: true
                    implicitHeight: Math.min(scrimOverlay.height - dialogMargins * 8 - dialogTitle.height - dialogButtonsRowLayout.height, devicesColumnLayout.implicitHeight)
                    
                    contentHeight: devicesColumnLayout.implicitHeight

                    ColumnLayout {
                        id: devicesColumnLayout
                        anchors.fill: parent
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: ScriptModel {
                                values: Pipewire.nodes.values.filter(node => {
                                    return !node.isStream && node.isSink !== root.deviceSelectorInput && node.audio
                                })
                            }

                            // This could and should be refractored, but all data becomes null when passed wtf
                            delegate: StyledRadioButton {
                                id: radioButton
                                required property var modelData
                                Layout.leftMargin: root.dialogMargins
                                Layout.rightMargin: root.dialogMargins
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                Layout.bottomMargin: 2
                                
                                Layout.minimumHeight: 28
                                description: modelData.description
                                checked: modelData.id === Pipewire.defaultAudioSink?.id
                                
                                // Override contentItem for smaller spacing and text
                                contentItem: Item {
                                    implicitHeight: Math.max(28, textItem.implicitHeight + 8)
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 8
                                        
                                        Rectangle {
                                            Layout.fillWidth: false
                                            Layout.alignment: Qt.AlignTop
                                            Layout.topMargin: 4
                                            width: 16
                                            height: 16
                                            radius: Appearance.rounding.full
                                            border.color: radioButton.checked ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurfaceVariant
                                            border.width: 2
                                            color: "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: radioButton.checked ? 8 : 3
                                                height: radioButton.checked ? 8 : 3
                                                radius: Appearance.rounding.full
                                                color: Appearance.colors.colPrimary
                                                opacity: radioButton.checked ? 1 : 0
                                                
                                                Behavior on opacity {
                                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                                }
                                                Behavior on width {
                                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                                }
                                                Behavior on height {
                                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                                }
                                            }
                                        }
                                        
                                        StyledText {
                                            id: textItem
                                            text: modelData.description
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            wrapMode: Text.Wrap
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                    }
                                }

                                Connections {
                                    target: root
                                    function onShowDeviceSelectorChanged() {
                                        if(!root.showDeviceSelector) return;
                                        radioButton.checked = (modelData.id === Pipewire.defaultAudioSink?.id)
                                    }
                                }

                                onCheckedChanged: {
                                    if (checked) {
                                        root.selectedDevice = modelData
                                    }
                                }
                            }
                        }
                        Item {
                            implicitHeight: dialogMargins
                        }
                    }
                }

                Rectangle {
                    color: Appearance.m3colors.m3outline
                    implicitHeight: 1
                    Layout.fillWidth: true
                    Layout.leftMargin: dialogMargins
                    Layout.rightMargin: dialogMargins
                }

                RowLayout {
                    id: dialogButtonsRowLayout
                    Layout.bottomMargin: dialogMargins
                    Layout.leftMargin: dialogMargins
                    Layout.rightMargin: dialogMargins
                    Layout.alignment: Qt.AlignRight

                    DialogButton {
                        buttonText: qsTr("Cancel")
                        onClicked: {
                            root.showDeviceSelector = false
                        }
                    }
                    DialogButton {
                        buttonText: qsTr("OK")
                        onClicked: {
                            root.showDeviceSelector = false
                            if (root.selectedDevice) {
                                if (root.deviceSelectorInput) {
                                    Pipewire.preferredDefaultAudioSource = root.selectedDevice
                                } else {
                                    Pipewire.preferredDefaultAudioSink = root.selectedDevice
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}