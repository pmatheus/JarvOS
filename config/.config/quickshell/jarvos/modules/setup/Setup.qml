pragma ComponentBehavior: Bound

import qs.components
import qs.services
import Caelestia
import Quickshell
import Quickshell.Io
import QtQuick

// "JarvOS Setup" — the first-run stage-2 panel. Opens itself once, when the
// installer's marker is present and the user has not finished or skipped yet;
// `jarvos-setup` reopens it any time through the IPC handler below.
Scope {
    id: root

    property var window: null
    // The panel greets the user once; closing it must not summon it back.
    property bool autoOpened

    readonly property bool isOpen: window !== null && window.visible

    function open(): void {
        // Must be given an owner: a window created with a null parent has
        // JavaScript ownership and disappears at the next garbage collection.
        if (!root.window)
            root.window = setupWindow.createObject(owner);
        root.window.visible = true;
        persist.wasOpen = true;
        JarvosSetup.refresh();
    }

    // Hiding rather than destroying keeps the user's selection if they reopen,
    // and keeps a compositor-side close from leaving a dangling reference.
    function close(): void {
        if (root.window)
            root.window.visible = false;
        persist.wasOpen = false;
    }

    Component.onCompleted: autoOpen.restart()

    QtObject {
        id: owner
    }

    // A config reload tears down dynamically created windows. Losing the panel
    // while an install is running is worse than putting it back.
    PersistentProperties {
        id: persist

        reloadableId: "jarvosSetup"

        property bool wasOpen

        onReloaded: {
            if (persist.wasOpen)
                Qt.callLater(root.open);
        }
    }

    Connections {
        target: JarvosSetup

        function onFirstRunChanged(): void {
            autoOpen.restart();
        }

        // Progress is visible outside the panel too, so the user can close it
        // and still learn how the install went.
        function onModuleFinished(id: string, ok: bool, name: string): void {
            if (ok)
                Toaster.toast(qsTr("%1 installed").arg(name), qsTr("JarvOS Setup finished this module."), "task_alt", Toast.Success);
            else
                Toaster.toast(qsTr("%1 failed").arg(name), JarvosSetup.progressFor(id).message, "error", Toast.Error);
        }
    }

    // Let the desktop draw before taking over the screen.
    Timer {
        id: autoOpen

        interval: 2500
        onTriggered: {
            if (JarvosSetup.firstRun && !root.autoOpened) {
                root.autoOpened = true;
                root.open();
            }
        }
    }

    IpcHandler {
        target: "setup"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function isOpen(): bool {
            return root.isOpen;
        }

        function status(): string {
            return JarvosSetup.overall;
        }
    }

    Component {
        id: setupWindow

        FloatingWindow {
            id: win

            title: qsTr("JarvOS Setup")
            color: Colours.tPalette.m3surface

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight
            minimumSize.width: content.implicitWidth
            minimumSize.height: content.implicitHeight

            Content {
                id: content

                anchors.fill: parent
                onCloseRequested: root.close()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
