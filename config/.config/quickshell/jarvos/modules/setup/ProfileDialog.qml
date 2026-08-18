pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One modal for both continuity doors. `restore` takes a repo URL (typed, or
// picked from `gh repo list`); `create` names the private repo that will be
// made. Restoring rewrites the machine and creating publishes a repo, so both
// state plainly what is about to happen before anything runs.
Item {
    id: root

    property string mode: "restore" // restore | create
    readonly property bool open: mode !== "" && shown
    property bool shown

    function show(which: string): void {
        root.mode = which;
        root.shown = true;
        if (which === "restore") {
            JarvosSync.loadRepos();
            Qt.callLater(() => urlField.forceActiveFocus());
        } else {
            Qt.callLater(() => nameField.forceActiveFocus());
        }
    }

    function hide(): void {
        root.shown = false;
    }

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.shown ? 1 : 0
    z: 90

    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.6)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (!JarvosSync.running)
                    root.hide();
            }
        }
    }

    StyledRect {
        anchors.centerIn: parent

        implicitWidth: 560
        implicitHeight: Math.min(root.height - Appearance.padding.large * 4, column.implicitHeight + Appearance.padding.large * 2)
        radius: Appearance.rounding.large
        color: Colours.palette.m3surfaceContainerHigh

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        ColumnLayout {
            id: column

            anchors.fill: parent
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    text: root.mode === "restore" ? "settings_backup_restore" : "cloud_upload"
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: root.mode === "restore" ? qsTr("Restore my profile") : qsTr("Create my profile")
                        font.pointSize: Appearance.font.size.larger
                        font.weight: 500
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.mode === "restore" ? qsTr("Installs the packages your profile lists, applies your dotfile changes and enables your units. Files it would overwrite are backed up first.") : qsTr("Creates a private GitHub repository holding what this machine has beyond stock JarvOS: extra packages, changed dotfiles, enabled units, and the names of the secrets you must bring yourself.")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ---- restore: URL field + gh picker ----

            Field {
                id: urlField

                Layout.fillWidth: true
                visible: root.mode === "restore"
                placeholder: qsTr("https://github.com/you/jarvos-profile")
                onAccepted: root.runRestore(false)
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.mode === "restore" && JarvosSync.reposError !== ""
                text: JarvosSync.reposError
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.mode === "restore" && JarvosSync.repos.length > 0
                text: qsTr("…or pick one of your repositories")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
            }

            StyledFlickable {
                id: repoFlick

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(180, repoColumn.height)
                visible: root.mode === "restore" && JarvosSync.repos.length > 0

                clip: true
                contentHeight: repoColumn.height
                flickableDirection: Flickable.VerticalFlick

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: repoFlick
                }

                ColumnLayout {
                    id: repoColumn

                    width: repoFlick.width - Appearance.padding.small
                    spacing: Appearance.spacing.small / 2

                    Repeater {
                        model: JarvosSync.repos

                        StyledRect {
                            id: repoRow

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: repoText.implicitHeight + Appearance.padding.normal * 2
                            radius: Appearance.rounding.small
                            color: urlField.text === repoRow.modelData.url ? Colours.palette.m3secondaryContainer : "transparent"

                            StateLayer {
                                radius: parent.radius

                                function onClicked(): void {
                                    urlField.text = repoRow.modelData.url;
                                }
                            }

                            RowLayout {
                                id: repoText

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Appearance.padding.normal

                                spacing: Appearance.spacing.small

                                MaterialIcon {
                                    text: repoRow.modelData.isPrivate ? "lock" : "public"
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Appearance.font.size.normal
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: repoRow.modelData.name
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ---- create: repo name ----

            Field {
                id: nameField

                Layout.fillWidth: true
                visible: root.mode === "create"
                text: "jarvos-profile"
                placeholder: qsTr("Repository name")
                onAccepted: root.runCreate()
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.mode === "create"
                text: qsTr("Secrets are never copied — only their names, so you know what to fetch from your vault.")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }

            // ---- shared footer ----

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.small
                spacing: Appearance.spacing.normal

                TextButton {
                    type: TextButton.Text
                    text: qsTr("Cancel")
                    enabled: !JarvosSync.running
                    opacity: enabled ? 1 : 0.5
                    onClicked: root.hide()
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    type: TextButton.Tonal
                    visible: root.mode === "restore"
                    text: qsTr("Preview")
                    enabled: !JarvosSync.running && urlField.text.trim() !== ""
                    opacity: enabled ? 1 : 0.5
                    onClicked: root.runRestore(true)
                }

                TextButton {
                    text: {
                        if (JarvosSync.running)
                            return qsTr("Working…");
                        return root.mode === "restore" ? qsTr("Restore") : qsTr("Create");
                    }
                    enabled: !JarvosSync.running && (root.mode === "create" ? nameField.text.trim() !== "" : urlField.text.trim() !== "")
                    opacity: enabled ? 1 : 0.5
                    onClicked: root.mode === "restore" ? root.runRestore(false) : root.runCreate()
                }
            }
        }
    }

    function runRestore(preview: bool): void {
        JarvosSync.restore(urlField.text, false, preview);
        root.hide();
    }

    function runCreate(): void {
        JarvosSync.createProfile(nameField.text);
        root.hide();
    }

    Behavior on opacity {
        Anim {}
    }

    component Field: StyledRect {
        id: field

        property alias text: input.text
        property string placeholder

        signal accepted

        implicitHeight: input.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surfaceContainer
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outline

        function forceActiveFocus(): void {
            input.forceActiveFocus();
        }

        StyledTextField {
            id: input

            anchors.fill: parent
            anchors.margins: Appearance.padding.normal

            placeholderText: field.placeholder
            verticalAlignment: TextInput.AlignVCenter
            onAccepted: field.accepted()
        }

        Behavior on border.color {
            CAnim {}
        }
    }
}
