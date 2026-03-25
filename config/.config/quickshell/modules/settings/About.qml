import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "root:/services/"
import "root:/modules/common/"
import "root:/modules/common/widgets/"

ContentPage {
    forceWidth: true

    ContentSection {
        title: "Distro"
        
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            IconImage {
                implicitSize: 100
                source: Quickshell.iconPath(SystemInfo.logo)
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: SystemInfo.distroName
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.normal
                    text: SystemInfo.homeUrl
                    textFormat: Text.MarkdownText
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            RippleButtonWithIcon {
                materialIcon: "auto_stories"
                mainText: "Documentation"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.documentationUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "support"
                mainText: "Help & Support"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.supportUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "bug_report"
                mainText: "Report a Bug"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.bugReportUrl)
                }
            }
            RippleButtonWithIcon {
                materialIcon: "policy"
                materialIconFill: false
                mainText: "Privacy Policy"
                onClicked: {
                    Qt.openUrlExternally(SystemInfo.privacyPolicyUrl)
                }
            }
            
        }

    }
    ContentSection {
        title: "Dotfiles"

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            MaterialSymbol {
                iconSize: 70
                text: "files"
                color: Appearance.colors.colOnSecondaryContainer
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                // spacing: 10
                StyledText {
                    text: "hypr-arch"
                    font.pixelSize: Appearance.font.pixelSize.title
                }
                StyledText {
                    text: "https://github.com/chsoares/hypr-arch"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    textFormat: Text.MarkdownText
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
                }
                StyledText {
                    text: "Based on"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                StyledText {
                    text: "https://github.com/end-4/dots-hyprland"
                    font.pixelSize: Appearance.font.pixelSize.small
                    textFormat: Text.MarkdownText
                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                    }
                    PointingHandLinkHover {}
                    color: Appearance.colors.colSubtext
                }
            }
        }

    }
}
