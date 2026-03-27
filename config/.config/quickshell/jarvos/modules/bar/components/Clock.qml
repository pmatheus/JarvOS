pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Appearance.padding.normal : Appearance.padding.small

    // High-frequency time state
    property string currentSeconds: "00"
    property string currentMillis: "000"

    implicitHeight: Config.bar.sizes.innerWidth
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    Timer {
        interval: 47
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            const s = now.getSeconds();
            const ms = now.getMilliseconds();
            root.currentSeconds = (s < 10 ? "0" : "") + s;
            root.currentMillis = (ms < 100 ? "0" : "") + (ms < 10 ? "0" : "") + ms;
        }
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Loader {
            anchors.verticalCenter: parent.verticalCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "schedule"
                color: root.colour
            }
        }

        // Date (horizontal)
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.bar.clock.showDate
            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format("ddd d")
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.sans
            color: root.colour
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.bar.clock.showDate
            width: visible ? 1 : 0
            height: parent.height * 0.5
            color: root.colour
            opacity: 0.2
        }

        // Hours
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.hourStr
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            animate: true
            animateProp: "opacity"
            animateFrom: 0.4
            animateTo: 1
            animateDuration: 200
        }

        // Colon with pulse animation
        StyledText {
            id: colonHM
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        // Minutes
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.minuteStr
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
            animate: true
            animateProp: "opacity"
            animateFrom: 0.4
            animateTo: 1
            animateDuration: 200
        }

        // Seconds colon
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: colonHM.opacity * 0.7
        }

        // Seconds
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentSeconds
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.75
        }

        // Dot
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "."
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.35
        }

        // Milliseconds
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentMillis
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.mono
            color: root.colour
            opacity: 0.35
        }

        // AM/PM for 12-hour mode
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.services.useTwelveHourClock && Time.amPmStr.length > 0
            text: Time.amPmStr
            font.pointSize: Appearance.font.size.small
            font.family: Appearance.font.family.sans
            color: root.colour
            opacity: 0.6
        }
    }
}
