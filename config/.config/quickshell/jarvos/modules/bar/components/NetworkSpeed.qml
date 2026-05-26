pragma ComponentBehavior: Bound

import qs.components
import qs.components.misc
import qs.services
import qs.config
import Caelestia.Internal
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    // Set by Bar.qml so the chip can drive the bar popout system.
    property var bar: null

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Appearance.padding.normal
    readonly property color downColour: Colours.palette.m3primary
    readonly property color upColour: Colours.palette.m3secondary

    // Compact rate label, e.g. "1.2M" / "340K" / "0B".
    function fmtRate(bps: real): string {
        const f = NetworkUsage.formatBytes(bps);
        const u = f.unit.charAt(0); // B / K / M / G
        const v = f.value < 10 ? f.value.toFixed(1) : Math.round(f.value).toString();
        return `${v}${u}`;
    }

    // Compact cumulative-total label (since shell start), e.g. "12.4G" / "340M".
    function fmtTotal(bytes: real): string {
        const f = NetworkUsage.formatBytesTotal(bytes);
        const u = f.unit.charAt(0); // B / K / M / G
        const v = f.value < 10 ? f.value.toFixed(1) : Math.round(f.value).toString();
        return `${v}${u}`;
    }

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Colours.tPalette.m3surfaceContainer.a)
    radius: Appearance.rounding.full

    // Keep NetworkUsage polling while this widget is alive.
    Ref {
        service: NetworkUsage
    }

    // Fixed width for the numeric labels so the chip size stays constant as
    // values update. Sized to the widest compact label (e.g. "1023M").
    TextMetrics {
        id: labelMetrics
        font.family: Appearance.font.family.mono
        font.pointSize: Appearance.font.size.smaller
        text: "8888M"
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        SparklineItem {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 34
            implicitHeight: Math.round(root.implicitHeight * 0.5)

            line1: NetworkUsage.uploadBuffer
            line1Color: root.upColour
            line1FillAlpha: 0.15
            line2: NetworkUsage.downloadBuffer
            line2Color: root.downColour
            line2FillAlpha: 0.2
            maxValue: Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024)
            historyLength: NetworkUsage.historyLength
        }

        // Download
        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "download"
            color: root.downColour
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: labelMetrics.width
            horizontalAlignment: Text.AlignRight
            text: root.fmtRate(NetworkUsage.downloadSpeed)
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.9
        }

        // Upload
        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "upload"
            color: root.upColour
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: labelMetrics.width
            horizontalAlignment: Text.AlignRight
            text: root.fmtRate(NetworkUsage.uploadSpeed)
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.9
        }

        // Separator between live rates and cumulative totals
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1
            Layout.preferredHeight: layout.height * 0.5
            color: root.colour
            opacity: 0.2
        }

        // Total downloaded (since shell start)
        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "swap_vert"
            color: root.colour
            opacity: 0.55
            font.pointSize: Appearance.font.size.small
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "south"
            color: root.downColour
            opacity: 0.7
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: labelMetrics.width
            horizontalAlignment: Text.AlignRight
            text: root.fmtTotal(NetworkUsage.downloadTotal)
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.75
        }

        // Total uploaded (since shell start)
        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "north"
            color: root.upColour
            opacity: 0.7
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: labelMetrics.width
            horizontalAlignment: Text.AlignRight
            text: root.fmtTotal(NetworkUsage.uploadTotal)
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.75
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            const popouts = root.bar?.popouts;
            if (!popouts)
                return;
            if (popouts.hasCurrent && popouts.currentName === "networkSpeed") {
                popouts.hasCurrent = false;
            } else {
                popouts.currentName = "networkSpeed";
                popouts.currentCenter = root.mapToItem(root.bar, root.implicitWidth / 2, 0).x;
                popouts.hasCurrent = true;
            }
        }
    }
}
