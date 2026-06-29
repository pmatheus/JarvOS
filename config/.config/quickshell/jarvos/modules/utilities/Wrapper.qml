pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property var visibilities
    required property Item sidebar
    required property Item popouts

    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property string recordingConfirmDelete
        property string recordingMode
        property bool updatesExpanded: false

        reloadableId: "utilities"
    }
    readonly property bool shouldBeActive: visibilities.sidebar || (visibilities.utilities && Config.utilities.enabled && !(visibilities.session && Config.session.enabled))

    visible: height > 0
    implicitHeight: root.shouldBeActive ? (content.item?.implicitHeight ?? 0) + Appearance.padding.large * 2 : 0
    implicitWidth: sidebar.visible ? sidebar.width : Config.utilities.sizes.width

    onShouldBeActiveChanged: {
        if (shouldBeActive && timer.running) {
            timer.triggered();
            timer.stop();
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: root.shouldBeActive ? Appearance.anim.durations.expressiveDefaultSpatial : Appearance.anim.durations.normal
            easing.bezierCurve: root.shouldBeActive ? Appearance.anim.curves.expressiveDefaultSpatial : Appearance.anim.curves.emphasized
        }
    }

    Timer {
        id: timer

        running: true
        interval: Appearance.anim.durations.extraLarge
        onTriggered: {
            content.active = Qt.binding(() => root.shouldBeActive || root.visible);
            content.visible = true;
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Appearance.padding.large

        visible: false
        active: true

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - Appearance.padding.large * 2
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
        }
    }
}
