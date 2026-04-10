pragma ComponentBehavior: Bound

import "services"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Appearance.rounding.large
    readonly property bool hasQuery: search.text.length > 0
    property bool showResults: false

    onHasQueryChanged: {
        if (hasQuery) {
            bufferTimer.restart();
        } else {
            bufferTimer.stop();
            showResults = false;
        }
    }

    // Debounce: wait for results to settle before first reveal
    Timer {
        id: bufferTimer
        interval: 180
        onTriggered: root.showResults = true
    }

    implicitWidth: Config.launcher.sizes.itemWidth + padding * 2
    implicitHeight: searchWrapper.height + resultsPanel.height + padding * 2

    // Search bar — standalone rounded pill
    StyledRect {
        id: searchWrapper

        color: Qt.alpha(Colours.palette.m3surface, 0.96)
        radius: Appearance.rounding.full

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small

            topPadding: Appearance.padding.larger
            bottomPadding: Appearance.padding.larger

            placeholderText: qsTr("JarvOS Search")

            onAccepted: search.launchCurrent(0)

            function launchCurrent(modifiers: int): void {
                const currentItem = list.currentList?.currentItem;
                if (!currentItem)
                    return;

                if (list.showWallpapers) {
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(currentItem.modelData.path);
                    root.visibilities.launcher = false;
                } else if (text.startsWith(Config.launcher.actionPrefix)) {
                    if (text.startsWith(`${Config.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    const resolved = currentItem.item ?? currentItem;
                    if (resolved.modelData?._type === "file" || resolved.modelData?._type === "folder") {
                        const fileItem = resolved;
                        if (modifiers & Qt.ShiftModifier)
                            fileItem.openInTerminal();
                        else if (modifiers & Qt.AltModifier)
                            fileItem.openInFileManager();
                        else if (modifiers & Qt.ControlModifier)
                            fileItem.openWithAntigravity();
                        else
                            fileItem.openDefault();
                    } else {
                        const entry = resolved.modelData?.entry ?? resolved.modelData;
                        Apps.launch(entry);
                        root.visibilities.launcher = false;
                    }
                }
            }

            Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
            Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

            Keys.onEscapePressed: root.visibilities.launcher = false

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & (Qt.ShiftModifier | Qt.AltModifier | Qt.ControlModifier)) {
                        search.launchCurrent(event.modifiers);
                        event.accepted = true;
                        return;
                    }
                }

                if (!Config.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                target: root.visibilities

                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher)
                        search.text = "";
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session)
                        search.forceActiveFocus();
                }
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }
    }

    // Results panel — clips content, reveals by growing height
    Item {
        id: resultsPanel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchWrapper.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: Appearance.spacing.small

        height: root.showResults ? resultsBg.implicitHeight : 0
        clip: true

        Behavior on height {
            Anim {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        }

        // Content is always full-size inside, just clipped by parent
        StyledRect {
            id: resultsBg

            anchors.left: parent.left
            anchors.right: parent.right
            // Pinned to top so clip reveals from top down
            anchors.top: parent.top

            color: Qt.alpha(Colours.palette.m3surface, 0.96)
            radius: root.rounding

            implicitHeight: list.height + root.padding * 2

            ContentList {
                id: list

                anchors.top: parent.top
                anchors.topMargin: root.padding
                anchors.horizontalCenter: parent.horizontalCenter

                content: root
                visibilities: root.visibilities
                panels: root.panels
                maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 4
                search: search
                padding: root.padding
                rounding: root.rounding
            }
        }
    }
}
