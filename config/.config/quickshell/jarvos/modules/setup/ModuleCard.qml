pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var module
    required property bool selected
    readonly property var state: JarvosSetup.progressFor(module.id)
    // What is actually on the machine, from the package query — never the last
    // run's status, which goes stale the moment a package is removed.
    readonly property bool installed: module.packages > 0 && module.installed >= module.packages
    readonly property bool running: state.status === "running" || state.status === "pending"
    readonly property bool failed: state.status === "failed" && !installed

    // Prefer what pacman says this will actually pull right now over the
    // module file's hand-written figure: a card promising 200 MB that pulls
    // 4 GB is how trust dies. The static estimate is only the offline fallback.
    readonly property string sizeText: {
        const bytes = root.module.download_bytes ?? -1;
        const aur = root.module.aur_pending ?? 0;
        // -1 is "pacman could not tell us"; only then is the module file's
        // hand-written figure worth showing.
        if (bytes < 0 && aur <= 0)
            return root.module.size_estimate;
        const parts = [];
        if (bytes > 0)
            parts.push(qsTr("%1 to download").arg(root.formatBytes(bytes)));
        else if (aur <= 0)
            parts.push(qsTr("already in the package cache"));
        if (aur > 0)
            parts.push(qsTr("%1 to build from the AUR").arg(aur));
        if (root.module.needs_toolchain)
            parts.push(qsTr("build toolchain first"));
        return parts.join(qsTr(" · "));
    }

    function formatBytes(bytes: real): string {
        if (bytes >= 1024 * 1024 * 1024)
            return qsTr("%1 GiB").arg((bytes / (1024 * 1024 * 1024)).toFixed(1));
        if (bytes >= 1024 * 1024)
            return qsTr("%1 MiB").arg(Math.round(bytes / (1024 * 1024)));
        return qsTr("%1 KiB").arg(Math.round(bytes / 1024));
    }
    readonly property real fraction: state.total > 0 ? state.done / state.total : 0
    readonly property int aurPending: module.aur_pending ?? 0
    // Anything the binary repo does not serve is compiled here, on the user's
    // machine. A handful is a minute; a security toolkit is an evening. Say so
    // before the click, not after.
    readonly property bool longBuild: !installed && !running && aurPending >= 5

    signal toggled

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: {
        if (root.failed)
            return Colours.palette.m3errorContainer;
        if (root.selected && !root.installed)
            return Colours.palette.m3primaryContainer;
        return Colours.tPalette.m3surfaceContainer;
    }

    StateLayer {
        disabled: root.installed || root.running || JarvosSetup.busy
        radius: parent.radius

        function onClicked(): void {
            root.toggled();
        }
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.large

        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2

                radius: Appearance.rounding.full
                color: root.failed ? Colours.palette.m3error : root.installed ? Colours.palette.m3success : root.selected ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: root.failed ? "error" : root.installed ? "check" : root.module.icon
                    color: root.failed ? Colours.palette.m3onError : root.installed ? Colours.palette.m3onSuccess : root.selected ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.large
                    fill: root.selected || root.installed ? 1 : 0

                    Behavior on fill {
                        Anim {}
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.module.name
                    font.pointSize: Appearance.font.size.normal
                    font.weight: 500
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.module.description
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.spacing.small / 2
                    text: {
                        if (root.running && root.state.total > 0)
                            return qsTr("%1 of %2 packages").arg(root.state.done).arg(root.state.total);
                        if (root.installed)
                            return qsTr("%1 packages · installed").arg(root.module.packages);
                        if (root.module.installed > 0)
                            return qsTr("%1 packages (%2 already here) · %3").arg(root.module.packages).arg(root.module.installed).arg(root.sizeText);
                        return qsTr("%1 packages · %2").arg(root.module.packages).arg(root.sizeText);
                    }
                    color: Colours.palette.m3outline
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: !root.running

                text: root.installed ? "task_alt" : root.selected ? "check_circle" : "radio_button_unchecked"
                color: root.installed ? Colours.palette.m3success : root.selected ? Colours.palette.m3primary : Colours.palette.m3outline
                font.pointSize: Appearance.font.size.large
                fill: root.selected && !root.installed ? 1 : 0
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: root.running

                text: "progress_activity"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large

                RotationAnimation on rotation {
                    running: root.running
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1400
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            visible: root.running

            implicitHeight: Appearance.padding.small
            radius: Appearance.rounding.full
            // The track has to read against the selected card's own container
            // colour, so derive it from the fill rather than a fixed role.
            color: Qt.alpha(Colours.palette.m3primary, 0.25)

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: parent.width * root.fraction
                radius: parent.radius
                color: Colours.palette.m3primary

                Behavior on width {
                    Anim {}
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.running || root.failed
            spacing: Appearance.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: root.state.message
                color: root.failed ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            TextButton {
                visible: root.failed && root.state.log !== ""
                type: TextButton.Text
                text: qsTr("View log")
                onClicked: JarvosSetup.openLog(root.state.log)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small / 2
            visible: root.longBuild
            spacing: Appearance.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignTop
                text: "hourglass_top"
                color: Colours.palette.m3tertiary
                font.pointSize: Appearance.font.size.normal
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("%1 of these are compiled on this machine — that can take hours. The desktop stays usable while it runs.").arg(root.aurPending)
                color: Colours.palette.m3tertiary
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.failed && root.state.failed !== ""
            text: qsTr("Failed: %1").arg(root.state.failed)
            color: Colours.palette.m3onErrorContainer
            font.pointSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }
    }
}
