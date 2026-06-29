import QtQuick
import QtQuick.Layouts
import "cards"
import qs.config

Item {
    id: root

    required property var props
    required property var visibilities
    required property Item popouts

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Appearance.spacing.normal

        IdleInhibit {
        }

        Record {
            props: root.props
            visibilities: root.visibilities
            z: 1
        }

        Updates {
            props: root.props
            visibilities: root.visibilities
        }

        Toggles {
            visibilities: root.visibilities
            popouts: root.popouts
        }

    }

    RecordingDeleteModal {
        props: root.props
    }

}
