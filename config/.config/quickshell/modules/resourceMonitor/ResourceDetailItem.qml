import "root:/modules/common"
import "root:/modules/common/widgets"
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string iconName: ""
    property string resourceName: ""
    property real percentage: 0
    property string absoluteValue: ""
    property string additionalInfo: ""
    property bool compact: false

    implicitHeight: compact ? 36 : 56
    implicitWidth: parent ? parent.width : 300

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        radius: Appearance.rounding.small

        RowLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 16

            // Icon with progress ring
            Item {
                Layout.preferredWidth: root.compact ? 28 : 40
                Layout.preferredHeight: root.compact ? 28 : 40
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.centerIn: parent
                    lineWidth: root.compact ? 2 : 3
                    value: root.percentage
                    size: root.compact ? 28 : 40
                    secondaryColor: Appearance.colors.colSecondaryContainer
                    primaryColor: root.percentage > 0.8 ? 
                        Appearance.colors.colError : 
                        root.percentage > 0.6 ? 
                            Appearance.colors.colWarning : 
                            Appearance.m3colors.m3onSecondaryContainer
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.iconName
                        iconSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                        color: root.percentage > 0.8 ? 
                            Appearance.colors.colError : 
                            root.percentage > 0.6 ? 
                                Appearance.colors.colWarning : 
                                Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }

            // Text information
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                
                StyledText {
                    Layout.fillWidth: true
                    text: root.resourceName
                    font.pixelSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: root.absoluteValue
                    font.pixelSize: root.compact ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: root.percentage > 0.8 ? 
                        Appearance.colors.colError : 
                        root.percentage > 0.6 ? 
                            Appearance.colors.colWarning : 
                            Appearance.colors.colOnLayer1
                }
            }
        }
    }
}