import "../services"
import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    required property var modelData
    required property PersistentProperties visibilities

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        id: stateLayer

        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.openDefault();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true

        onClicked: mouse => {
            if (mouse.modifiers & Qt.ShiftModifier)
                root.openInTerminal();
            else if (mouse.modifiers & Qt.AltModifier)
                root.openInFileManager();
            else if (mouse.modifiers & Qt.ControlModifier)
                root.openWithAntigravity();
            else
                root.openDefault();
        }
    }

    function openDefault(): void {
        if (modelData.isDir)
            Quickshell.execDetached(["xdg-open", modelData.path]);
        else
            Quickshell.execDetached(["xdg-open", modelData.path]);
        visibilities.launcher = false;
    }

    function openInTerminal(): void {
        const dir = modelData.isDir ? modelData.path : modelData.path.replace(/\/[^/]*$/, "");
        Quickshell.execDetached(["kitty", "-1", "--directory", dir]);
        visibilities.launcher = false;
    }

    function openInFileManager(): void {
        const dir = modelData.isDir ? modelData.path : modelData.path.replace(/\/[^/]*$/, "");
        Quickshell.execDetached(["nautilus", dir]);
        visibilities.launcher = false;
    }

    function openWithAntigravity(): void {
        Quickshell.execDetached(["antigravity", modelData.path]);
        visibilities.launcher = false;
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.larger
        anchors.rightMargin: Appearance.padding.larger
        anchors.margins: Appearance.padding.smaller

        MaterialIcon {
            id: icon

            text: root.modelData.isDir ? "folder" : "description"
            fill: root.modelData.isDir ? 1 : 0
            color: root.modelData.isDir ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.larger

            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            anchors.left: icon.right
            anchors.leftMargin: Appearance.spacing.normal
            anchors.right: hintIcon.left
            anchors.rightMargin: Appearance.spacing.small
            anchors.verticalCenter: icon.verticalCenter

            implicitHeight: name.implicitHeight + pathText.implicitHeight

            StyledText {
                id: name

                text: root.modelData.name ?? ""
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideMiddle
                width: parent.width
            }

            StyledText {
                id: pathText

                text: {
                    const p = root.modelData.path ?? "";
                    const home = Quickshell.env("HOME");
                    return p.startsWith(home) ? "~" + p.slice(home.length) : p;
                }
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3outline
                elide: Text.ElideMiddle
                width: parent.width

                anchors.top: name.bottom
            }
        }

        MaterialIcon {
            id: hintIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            text: root.modelData.isDir ? "folder_open" : "open_in_new"
            color: Colours.palette.m3outline
            font.pointSize: Appearance.font.size.small
            opacity: 0.6
        }
    }
}
