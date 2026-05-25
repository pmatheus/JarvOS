pragma ComponentBehavior: Bound

import qs.components
import qs.components.misc
import qs.services
import qs.config
import Caelestia.Internal
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Item wrapper

    readonly property int contentWidth: 320

    function fmtSpeed(bps: real): string {
        const f = NetworkUsage.formatBytes(bps);
        return `${f.value < 10 ? f.value.toFixed(2) : f.value.toFixed(1)} ${f.unit}`;
    }

    function fmtTotal(bytes: real): string {
        const f = NetworkUsage.formatBytesTotal(bytes);
        return `${f.value.toFixed(2)} ${f.unit}`;
    }

    implicitWidth: contentWidth
    implicitHeight: child.implicitHeight

    // Keep NetworkUsage polling while the popout is open.
    Ref {
        service: NetworkUsage
    }

    ColumnLayout {
        id: child

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "swap_vert"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: "Network"
                font.pointSize: Appearance.font.size.normal
                font.bold: true
            }
        }

        // Live graph
        SparklineItem {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            implicitHeight: 60

            line1: NetworkUsage.uploadBuffer
            line1Color: Colours.palette.m3secondary
            line1FillAlpha: 0.15
            line2: NetworkUsage.downloadBuffer
            line2Color: Colours.palette.m3primary
            line2FillAlpha: 0.2
            maxValue: Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024)
            historyLength: NetworkUsage.historyLength
        }

        // Current speeds: download + upload
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            spacing: Appearance.spacing.normal

            Stat {
                Layout.fillWidth: true
                icon: "download"
                accent: Colours.palette.m3primary
                label: "Down"
                value: root.fmtSpeed(NetworkUsage.downloadSpeed)
            }

            Stat {
                Layout.fillWidth: true
                icon: "upload"
                accent: Colours.palette.m3secondary
                label: "Up"
                value: root.fmtSpeed(NetworkUsage.uploadSpeed)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            Layout.bottomMargin: Appearance.spacing.small / 2
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Session totals (GB)
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Stat {
                Layout.fillWidth: true
                icon: "south"
                accent: Colours.palette.m3primary
                label: "Total ↓"
                value: root.fmtTotal(NetworkUsage.downloadTotal)
            }

            Stat {
                Layout.fillWidth: true
                icon: "north"
                accent: Colours.palette.m3secondary
                label: "Total ↑"
                value: root.fmtTotal(NetworkUsage.uploadTotal)
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "since shell start"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
            opacity: 0.7
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        // Open the full networking config (wifi / cable / vpn)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: settingsRow.implicitHeight + Appearance.padding.small * 2
            radius: Appearance.rounding.small
            color: "transparent"

            StateLayer {
                radius: parent.radius

                function onClicked(): void {
                    root.wrapper.detach("network");
                }
            }

            RowLayout {
                id: settingsRow

                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.small
                anchors.rightMargin: Appearance.padding.small
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "settings_ethernet"
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "Network settings"
                    font.pointSize: Appearance.font.size.smaller
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: "wifi · cable · vpn"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    opacity: 0.8
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    // A labelled icon + value stat block.
    component Stat: RowLayout {
        id: stat

        property string icon
        property string label
        property string value
        property color accent: Colours.palette.m3onSurface

        spacing: Appearance.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: stat.icon
            color: stat.accent
            font.pointSize: Appearance.font.size.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: stat.label
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.fillWidth: true
                text: stat.value
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }
}
