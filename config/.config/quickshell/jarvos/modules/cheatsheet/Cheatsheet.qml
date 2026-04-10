pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.effects
import qs.components.misc
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Scope {
    id: cheatRoot

    property var keybindColumns: []

    function subKey(key: string): string {
        const subs = {
            "Super": "Super",
            "Return": "Enter",
            "Print": "PrtSc",
            "Slash": "/",
            "Hash": "#",
            "Semicolon": ";",
            "BracketLeft": "[",
            "BracketRight": "]",
            "Minus": "\u2212",
            "Equal": "=",
            "Period": ".",
            "Comma": ",",
            "Escape": "Esc",
            "Page_Down": "PgDn",
            "Page_Up": "PgUp",
            "Backslash": "\\",
            "Delete": "Del",
            "Tab": "Tab",
            "Backtab": "Tab"
        };
        return subs[key] ?? key;
    }

    function cleanComment(comment: string): string {
        if (!comment) return "";
        let c = comment.replace(/^Execute:\s*/, "");
        c = c.replace(/~\/\.config\/[^\s]+\/scripts\/[^\s]*\/(\S+\.sh)/, "$1");
        c = c.replace(/~\/\.config\/[^\s]+\/(\S+)/, "$1");
        if (c.length > 35) c = c.substring(0, 32) + "\u2026";
        return c;
    }

    function buildColumns(rawChildren: var): var {
        let sections = [];
        for (const col of rawChildren) {
            for (const sec of (col.children ?? [])) {
                if ((sec.keybinds ?? []).length > 0)
                    sections.push(sec);
            }
        }

        let compacted = [];
        for (const sec of sections) {
            const kb = compactKeybinds(sec.keybinds ?? []);
            if (kb.length > 0)
                compacted.push({ name: sec.name, keybinds: kb });
        }

        let final = [];
        for (const sec of compacted) {
            if (sec.keybinds.length > 20) {
                const mid = Math.ceil(sec.keybinds.length / 2);
                final.push({ name: sec.name, keybinds: sec.keybinds.slice(0, mid) });
                final.push({ name: sec.name + " \u2026", keybinds: sec.keybinds.slice(mid) });
            } else {
                final.push(sec);
            }
        }

        final.sort((a, b) => (b.keybinds?.length ?? 0) - (a.keybinds?.length ?? 0));

        const totalItems = final.reduce((sum, s) => sum + (s.keybinds?.length ?? 0) + 2, 0);
        const maxPerCol = 22;
        const numCols = Math.max(3, Math.min(5, Math.ceil(totalItems / maxPerCol)));

        let columns = [];
        let colHeights = [];
        for (let i = 0; i < numCols; i++) { columns.push([]); colHeights.push(0); }

        for (const sec of final) {
            const h = (sec.keybinds?.length ?? 0) + 2;
            let minIdx = 0;
            for (let i = 1; i < numCols; i++) {
                if (colHeights[i] < colHeights[minIdx]) minIdx = i;
            }
            columns[minIdx].push(sec);
            colHeights[minIdx] += h;
        }

        return columns.filter(c => c.length > 0);
    }

    function compactKeybinds(keybinds: var): var {
        let result = [];
        let seen = new Set();
        let wsNums = [];
        let sendWsNums = [];

        for (const kb of keybinds) {
            const comment = kb.comment ?? "";
            const key = kb.key ?? "";
            const mods = (kb.mods ?? []).join("+");
            const sig = mods + "+" + key;

            if (!comment && !key) continue;
            if (seen.has(sig)) continue;
            seen.add(sig);

            const wsMatch = comment.match(/^Workspace (\d+)$/);
            if (wsMatch && mods === "Super" && /^\d$/.test(key)) {
                wsNums.push(wsMatch[1]);
                continue;
            }

            const sendMatch = comment.match(/^Send to workspace (\d+)$/);
            if (sendMatch && /^\d$/.test(key)) {
                sendWsNums.push(sendMatch[1]);
                continue;
            }

            if (key.startsWith("mouse:")) continue;
            if (comment.startsWith("Launch:") && result.some(r => r.comment === comment)) continue;

            result.push(kb);
        }

        if (wsNums.length > 0)
            result.push({ mods: ["Super"], key: "1\u20130", comment: "Workspace 1\u201310" });
        if (sendWsNums.length > 0)
            result.push({ mods: ["Super", "Shift"], key: "1\u20130", comment: "Send to workspace 1\u201310" });

        return result;
    }

    property bool cheatsheetVisible: false

    onCheatsheetVisibleChanged: {
        if (cheatsheetVisible) {
            cursorProc.running = true;
        }
    }
    onKeybindColumnsChanged: columnsModel.values = cheatRoot.keybindColumns

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const pos = JSON.parse(data);
                    for (const s of Quickshell.screens) {
                        if (pos.x >= s.x && pos.x < s.x + s.width) {
                            win.screen = s;
                            return;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    PanelWindow {
        id: win

        visible: cheatRoot.cheatsheetVisible
        WlrLayershell.namespace: "caelestia-cheatsheet"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        ScriptModel {
            id: columnsModel
        }

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        HyprlandFocusGrab {
            windows: [win]
            active: cheatRoot.cheatsheetVisible
            onCleared: {
                if (cheatRoot.cheatsheetVisible)
                    cheatRoot.cheatsheetVisible = false;
            }
        }

        Item {
            anchors.fill: parent

            // Scrim
            Rectangle {
                anchors.fill: parent
                color: "#55000000"
                MouseArea {
                    anchors.fill: parent
                    onClicked: cheatRoot.cheatsheetVisible = false
                }
            }

            // Card — only on focused monitor
            Rectangle {
                id: card
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height * 0.60
                color: "#1e1e2e"
                radius: Appearance.rounding.large

                focus: visible
                Keys.onEscapePressed: cheatRoot.cheatsheetVisible = false

                // Subtle inner border
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: parent.radius
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                }

                // Title row
                Row {
                    id: titleRow
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "keyboard"
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keyboard Shortcuts"
                        font.pointSize: Appearance.font.size.larger
                        font.weight: Font.Medium
                        color: Colours.palette.m3onSurface
                    }
                }

                // Divider
                Rectangle {
                    id: divider
                    anchors.top: titleRow.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 20
                    height: 1
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
                }

                // Content
                RowLayout {
                    id: contentLayout
                    anchors.top: divider.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    spacing: 20

                    // Column separators handled by delegates
                    Repeater {
                        model: columnsModel

                        delegate: RowLayout {
                            required property var modelData
                            required property int index

                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            spacing: 0

                            // Column content
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                spacing: 10

                                Repeater {
                                    model: modelData

                                    delegate: ColumnLayout {
                                        required property var modelData
                                        spacing: 3

                                        // Section header with accent bar
                                        Row {
                                            spacing: 6

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 3
                                                height: sectionTitle.implicitHeight
                                                radius: 2
                                                color: Colours.palette.m3primary
                                            }

                                            StyledText {
                                                id: sectionTitle
                                                text: modelData.name
                                                font.pointSize: Appearance.font.size.small
                                                font.weight: Font.DemiBold
                                                color: Colours.palette.m3onSurface
                                            }
                                        }

                                        // Keybind rows
                                        Repeater {
                                            model: modelData.keybinds ?? []

                                            delegate: Row {
                                                required property var modelData
                                                spacing: 6
                                                height: 20

                                                // Key combo
                                                Row {
                                                    spacing: 3
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Repeater {
                                                        model: modelData.mods

                                                        delegate: Rectangle {
                                                            required property var modelData
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: "#2a2a3e"
                                                            radius: 4
                                                            width: modL.implicitWidth + 8
                                                            height: modL.implicitHeight + 4
                                                            border.width: 1
                                                            border.color: Qt.alpha(Colours.palette.m3outline, 0.15)

                                                            StyledText {
                                                                id: modL
                                                                anchors.centerIn: parent
                                                                text: cheatRoot.subKey(modelData)
                                                                font.pointSize: Appearance.font.size.smaller
                                                                font.family: Appearance.font.family.mono
                                                                color: Colours.palette.m3onSurface
                                                            }
                                                        }
                                                    }

                                                    StyledText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: modelData.mods.length > 0 && modelData.key !== "Super_L"
                                                        text: "+"
                                                        font.pointSize: Appearance.font.size.smaller
                                                        color: Qt.alpha(Colours.palette.m3outline, 0.5)
                                                    }

                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        visible: modelData.key !== "Super_L"
                                                        color: Colours.palette.m3primaryContainer
                                                        radius: 4
                                                        width: keyL.implicitWidth + 8
                                                        height: keyL.implicitHeight + 4
                                                        border.width: 1
                                                        border.color: Qt.alpha(Colours.palette.m3primary, 0.2)

                                                        StyledText {
                                                            id: keyL
                                                            anchors.centerIn: parent
                                                            text: cheatRoot.subKey(modelData.key)
                                                            font.pointSize: Appearance.font.size.smaller
                                                            font.family: Appearance.font.family.mono
                                                            color: Colours.palette.m3onPrimaryContainer
                                                        }
                                                    }
                                                }

                                                // Description
                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: cheatRoot.cleanComment(modelData.comment)
                                                    font.pointSize: Appearance.font.size.smaller
                                                    color: Colours.palette.m3onSurfaceVariant
                                                    elide: Text.ElideRight
                                                    width: Math.min(implicitWidth, 150)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Vertical separator between columns
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                visible: index < cheatRoot.keybindColumns.length - 1
                                width: 1
                                Layout.fillHeight: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.2)
                            }
                        }
                    }
                }

                // Hint at bottom
                StyledText {
                    id: hintText
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Esc to close"
                    font.pointSize: Appearance.font.size.smaller
                    color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.4)
                }
            }
        }
    }

    property var _defaultKb: []
    property var _customKb: []

    function _mergeKb(): void {
        const all = [..._defaultKb, ..._customKb];
        const cols = buildColumns(all);
        cheatRoot.keybindColumns = cols;
    }

    Process {
        id: defaultProc
        running: true
        command: ["python3",
                  `${Quickshell.env("HOME")}/.config/quickshell/scripts/hyprland/get_keybinds.py`,
                  "--show-hidden",
                  "--path", `${Quickshell.env("HOME")}/.config/hypr/hyprland/keybinds.conf`]


        stdout: SplitParser {
            onRead: data => {
                try {
                    cheatRoot._defaultKb = JSON.parse(data).children ?? [];
                    cheatRoot._mergeKb();
                } catch (e) {
                    console.error("[Cheatsheet] Parse error:", e);
                }
            }
        }
    }

    Process {
        id: customProc
        running: true
        command: ["python3",
                  `${Quickshell.env("HOME")}/.config/quickshell/scripts/hyprland/get_keybinds.py`,
                  "--show-hidden",
                  "--path", `${Quickshell.env("HOME")}/.config/hypr/hyprland/custom/keybinds.conf`]

        stdout: SplitParser {
            onRead: data => {
                try {
                    cheatRoot._customKb = JSON.parse(data).children ?? [];
                    cheatRoot._mergeKb();
                } catch (e) {}
            }
        }
    }

    CustomShortcut {
        name: "cheatsheet"
        description: "Toggle keybinds cheatsheet"
        onPressed: cheatRoot.cheatsheetVisible = !cheatRoot.cheatsheetVisible
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { cheatRoot.cheatsheetVisible = !cheatRoot.cheatsheetVisible; }
        function open(): void { cheatRoot.cheatsheetVisible = true; }
        function close(): void { cheatRoot.cheatsheetVisible = false; }
    }
}
