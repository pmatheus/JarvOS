import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// The brand lands here — this panel is the first thing a new machine shows —
// so the header is given room rather than being squeezed into a title bar.
// Mark plus wordmark reproduce brand/jarvos-lockup.svg: same geometry, same
// Rubik 500, same letter-spacing ratio, tinted with the live accent.
ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: Appearance.spacing.large

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.large

        BrandMark {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 72
            implicitHeight: 72
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true

            text: "JARVOS"
            color: Colours.palette.m3primary
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: 500
            // 14/88 of the type size, as in the lockup.
            font.letterSpacing: Appearance.font.size.extraLarge * 14 / 88
        }
    }

    StyledText {
        Layout.fillWidth: true

        text: qsTr("Your desktop is already running. Pick what else you want and it installs in the background — keep using the machine.")
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.WordWrap
    }
}
