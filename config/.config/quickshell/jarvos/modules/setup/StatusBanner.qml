pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// One line that always says what the machine is doing, whether that is a module
// install or a jarvos-sync run, and — after a restore — the honest "you are not
// done yet" list of secrets the profile could not carry.
StyledRect {
    id: root

    readonly property bool syncing: JarvosSync.running
    readonly property bool syncDone: JarvosSync.finished && JarvosSync.action !== ""
    readonly property bool showSecrets: JarvosSync.finished && JarvosSync.status === "done" && JarvosSync.action === "restore" && secretNames.length > 0
    property list<string> secretNames: []

    readonly property string label: {
        if (root.syncing) {
            const what = JarvosSync.action === "restore" ? qsTr("Restoring your profile") : qsTr("Creating your profile");
            const phase = JarvosSync.phase === "" ? "" : qsTr(" — %1").arg(JarvosSync.phase);
            return `${what}${phase}: ${JarvosSync.message}`;
        }
        if (root.syncDone && JarvosSync.status === "failed")
            return qsTr("%1 failed: %2").arg(JarvosSync.action).arg(JarvosSync.message);
        if (root.syncDone && JarvosSync.status === "done" && JarvosSync.action === "init")
            return qsTr("Profile repository created. Keep it current with `jarvos-sync push`.");
        if (root.syncDone && JarvosSync.status === "done" && JarvosSync.action === "restore")
            return JarvosSync.dryRun ? qsTr("Preview only — nothing was changed. Open the log to see exactly what a real restore would do.") : qsTr("Profile restored. Open the log for what changed.");
        if (JarvosSetup.overall === "done")
            return qsTr("All done. You can close this — reopen it any time with `jarvos-setup`.");
        if (JarvosSetup.overall === "failed")
            return qsTr("Some packages did not install. Open the log on the card for details.");
        if (JarvosSetup.current !== "")
            return qsTr("Installing %1 — you can close this window, it keeps going.").arg(JarvosSetup.moduleName(JarvosSetup.current));
        return JarvosSetup.message || qsTr("Working…");
    }

    readonly property bool failed: (root.syncDone && JarvosSync.status === "failed") || (!root.syncing && JarvosSetup.overall === "failed")
    readonly property bool ok: !root.failed && ((root.syncDone && JarvosSync.status === "done") || JarvosSetup.overall === "done")

    Layout.fillWidth: true
    visible: JarvosSetup.busy || JarvosSetup.overall === "done" || JarvosSetup.overall === "failed" || root.syncing || root.syncDone

    implicitHeight: layout.implicitHeight + Appearance.padding.normal * 2
    radius: Appearance.rounding.normal
    color: root.failed ? Colours.palette.m3errorContainer : Colours.tPalette.m3surfaceContainerHigh

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.normal

        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                text: {
                    if (root.failed)
                        return "warning";
                    if (root.ok)
                        return "task_alt";
                    return root.syncing ? "cloud_sync" : "downloading";
                }
                color: root.failed ? Colours.palette.m3error : root.ok ? Colours.palette.m3success : Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: root.failed ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
            }

            TextButton {
                type: TextButton.Text
                visible: JarvosSync.log !== "" && (root.syncing || root.syncDone)
                text: qsTr("Log")
                onClicked: JarvosSync.openLog()
            }
        }

        // Coarse phase progress; indeterminate when jarvos-sync cannot yet say
        // how many steps the phase has.
        StyledRect {
            Layout.fillWidth: true
            visible: root.syncing

            implicitHeight: Appearance.padding.small
            radius: Appearance.rounding.full
            color: Qt.alpha(Colours.palette.m3primary, 0.25)

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: parent.width * (JarvosSync.indeterminate ? pulse.value : JarvosSync.fraction)
                radius: parent.radius
                color: Colours.palette.m3primary

                Behavior on width {
                    Anim {}
                }
            }

            QtObject {
                id: pulse

                property real value: 0.15
            }

            SequentialAnimation {
                running: root.syncing && JarvosSync.indeterminate
                loops: Animation.Infinite

                Anim {
                    target: pulse
                    property: "value"
                    from: 0.1
                    to: 0.6
                    duration: Appearance.anim.durations.large
                }
                Anim {
                    target: pulse
                    property: "value"
                    from: 0.6
                    to: 0.1
                    duration: Appearance.anim.durations.large
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.syncing && JarvosSync.phaseTotal > 0 && JarvosSync.phaseIndex > 0
            text: JarvosSync.stepTotal > 0 ? qsTr("Phase %1 of %2 · step %3 of %4").arg(JarvosSync.phaseIndex).arg(JarvosSync.phaseTotal).arg(JarvosSync.step).arg(JarvosSync.stepTotal) : qsTr("Phase %1 of %2").arg(JarvosSync.phaseIndex).arg(JarvosSync.phaseTotal)
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.small
        }

        // The closing screen of a restore: what the profile deliberately did not
        // carry, by name only.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.small
            visible: root.showSecrets
            spacing: Appearance.spacing.small / 2

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Still to bring from your vault (%1) — names only, no values were copied:").arg(root.secretNames.length)
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.secretNames.join(" · ")
                color: Colours.palette.m3onSurface
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.small
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }

    FileView {
        path: JarvosSync.secretsManifest
        printErrors: false
        // The path only appears when a restore ends, so it must be read
        // eagerly rather than waiting for someone to ask for the text.
        preload: true

        onLoaded: root.secretNames = text().split("\n").map(l => l.trim()).filter(l => l !== "" && !l.startsWith("#"))
        onLoadFailed: root.secretNames = []
    }
}
