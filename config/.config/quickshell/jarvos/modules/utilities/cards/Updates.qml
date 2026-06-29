import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var props
    required property var visibilities

    readonly property bool expanded: props.updatesExpanded ?? false
    readonly property string statusText: UpdateStatus.running ? qsTr("Checking updates") :
        UpdateStatus.error !== "" ? qsTr("Check failed") :
        UpdateStatus.generatedAt === "" ? qsTr("Not checked yet") :
        UpdateStatus.total === 0 ? qsTr("No package updates found") :
        qsTr("%1 update(s) available").arg(UpdateStatus.total)

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    onVisibleChanged: {
        if (visible && root.visibilities.utilities)
            UpdateStatus.refreshIfStale(10 * 60 * 1000);
    }

    Connections {
        target: root.visibilities

        function onUtilitiesChanged(): void {
            if (root.visibilities.utilities)
                UpdateStatus.refreshIfStale(10 * 60 * 1000);
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Appearance.padding.smaller * 2

                radius: Appearance.rounding.full
                color: UpdateStatus.total > 0 ? Colours.palette.m3tertiary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: UpdateStatus.running ? "sync" : "system_update_alt"
                    color: UpdateStatus.total > 0 ? Colours.palette.m3onTertiary : Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.large

                    RotationAnimation on rotation {
                        running: UpdateStatus.running
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Updates")
                    font.pointSize: Appearance.font.size.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.statusText
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "system_update_alt"
                disabled: UpdateStatus.running
                type: IconButton.Filled
                onClicked: Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.terminal, "bash", "-c", "yay -Syu --noconfirm; echo; echo 'Updates finished.'; sleep 4"])
            }

            // Dev toolchains/runtimes (rust, uv tools, flutter, bun). Each runs
            // only if installed; non-interactive. npm/pip excluded by bun/uv policy.
            IconButton {
                icon: "code"
                disabled: UpdateStatus.running
                type: IconButton.Tonal
                onClicked: Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.terminal, "bash", "-c", "for t in rustup uv flutter bun; do command -v $t >/dev/null || continue; case $t in rustup) rustup update;; uv) uv tool upgrade --all;; flutter) flutter upgrade;; bun) bun upgrade;; esac; done; echo; echo 'Dev tools atualizados.'; sleep 4"])
            }

            IconButton {
                icon: "refresh"
                disabled: UpdateStatus.running
                type: IconButton.Tonal
                onClicked: UpdateStatus.refresh()
            }

            IconButton {
                icon: root.expanded ? "expand_less" : "expand_more"
                type: IconButton.Text
                onClicked: root.props.updatesExpanded = !root.expanded
            }
        }

        StyledText {
            visible: UpdateStatus.error !== ""
            Layout.fillWidth: true
            text: UpdateStatus.error
            color: Colours.palette.m3error
            wrapMode: Text.Wrap
        }

        StyledFlickable {
            visible: root.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: root.expanded ? Math.min(detailsLayout.implicitHeight, 420) : 0
            contentWidth: width
            contentHeight: detailsLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: detailsLayout

                width: parent.width
                spacing: Appearance.spacing.small

                Repeater {
                    model: UpdateStatus.groups

                    delegate: StyledRect {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: groupLayout.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                        ColumnLayout {
                            id: groupLayout

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.normal
                            spacing: Appearance.spacing.smaller

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                MaterialIcon {
                                    text: modelData.icon
                                    color: modelData.status === "updates" ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.normal
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pointSize: Appearance.font.size.small
                                    font.weight: 500
                                    elide: Text.ElideRight
                                }

                                StyledRect {
                                    implicitWidth: countText.implicitWidth + Appearance.padding.small * 2
                                    implicitHeight: countText.implicitHeight + Appearance.padding.small
                                    radius: Appearance.rounding.full
                                    color: modelData.status === "updates" ? Colours.palette.m3tertiaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                                    StyledText {
                                        id: countText

                                        anchors.centerIn: parent
                                        text: modelData.status === "updates" ? modelData.count : modelData.status
                                        color: modelData.status === "updates" ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Math.round(Appearance.font.size.small * 0.85)
                                    }
                                }
                            }

                            StyledText {
                                visible: modelData.error && modelData.error !== ""

                                Layout.fillWidth: true
                                text: modelData.error
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: modelData.items.slice(0, 8)

                                delegate: StyledText {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    text: modelData
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.family: Appearance.font.family.mono
                                    font.pointSize: Math.round(Appearance.font.size.small * 0.85)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
