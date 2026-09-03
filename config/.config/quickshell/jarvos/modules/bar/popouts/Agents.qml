pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Item wrapper

    readonly property int contentWidth: 440

    property var fullData: ({ "sessions": [], "providers": {} })
    readonly property var sessions: fullData.sessions || []
    readonly property int sessionCount: sessions.length
    readonly property var providers: fullData.providers || {}

    property string activeCase: ""

    property string selectedAgent: "claude"
    readonly property var currentProvider: providers[selectedAgent] || null

    implicitWidth: contentWidth
    implicitHeight: child.implicitHeight

    function refresh(): void {
        if (!statusProc.running) statusProc.running = true;
        if (!caseProc.running) caseProc.running = true;
    }

    function refreshUsage(): void {
        if (!updateProc.running) updateProc.running = true;
    }

    Component.onCompleted: {
        refreshUsage();
        refresh();
    }

    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "agents") {
                root.refreshUsage();
                root.refresh();
            }
        }
    }

    Timer {
        id: liveUsageTimer
        interval: 10000
        running: root.wrapper.currentName === "agents"
        repeat: true
        onTriggered: {
            root.refreshUsage();
        }
    }

    Process {
        id: statusProc
        command: ["jarvos-agent-sessions", "--full"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fullData = JSON.parse(text);
                } catch (e) {
                    root.fullData = { "sessions": [], "providers": {} };
                }
            }
        }
    }

    Process {
        id: caseProc
        command: ["jarvos-case", "active"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeCase = text.trim();
            }
        }
    }

    Process {
        id: triageProc
        command: ["jarvos-hunt-triage"]
    }

    Process {
        id: updateProc
        command: ["jarvos-agent-usage-update"]
        onExited: root.refresh()
    }

    Process {
        id: focusProc
    }

    function focusSession(pid: int): void {
        focusProc.command = ["jarvos-agent-focus", pid.toString()];
        focusProc.running = true;
        root.wrapper.close();
    }

    Process {
        id: launchProc
        onExited: root.refresh()
    }

    function launchAgent(agentName: string): void {
        launchProc.command = ["jarvos-agent", agentName];
        launchProc.running = true;
    }

    function launchAgentInCase(agentName: string): void {
        launchProc.command = ["bash", "-c", `case_path="$(jarvos-case active --path 2>/dev/null)"; jarvos-agent "${agentName}" --cwd "\${case_path:-$HOME}"`];
        launchProc.running = true;
        root.wrapper.close();
    }

    function formatPercent(val: real): string {
        if (val === undefined || val === null) return "0%";
        return Math.round(val * 100) + "%";
    }

    function formatTimeRemaining(isoStr: string): string {
        if (!isoStr) return "";
        try {
            const target = new Date(isoStr).getTime();
            const now = Date.now();
            const diff = target - now;
            if (diff <= 0) return "resets soon";
            const hours = Math.floor(diff / (1000 * 60 * 60));
            const days = Math.floor(hours / 24);
            const remHours = hours % 24;
            if (days > 0) return `resets in ${days}d ${remHours}h`;
            return `resets in ${hours}h`;
        } catch (e) {
            return "";
        }
    }

    ColumnLayout {
        id: child

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Appearance.spacing.small

        // 1. Header with Title, Active Badge & Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "neurology"
                color: root.sessionCount > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.large
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: "AI Agent Workspace"
                    font.bold: true
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.sessionCount > 0 ? `${root.sessionCount} active session${root.sessionCount > 1 ? "s" : ""}` : "No active sessions"
                    font.pointSize: Appearance.font.size.smaller
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "refresh"
                type: IconButton.Tonal
                onClicked: {
                    root.refreshUsage();
                    root.refresh();
                }
            }
        }

        // 2. Active Threat Hunt Case Context Bar
        StyledRect {
            Layout.fillWidth: true
            radius: Appearance.rounding.small
            color: Colours.palette.m3surfaceContainer
            implicitHeight: 34

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                MaterialIcon {
                    text: "shield"
                    color: root.activeCase.length > 0 ? Colours.palette.m3primary : Colours.palette.m3outline
                    font.pointSize: Appearance.font.size.smaller
                }

                StyledText {
                    text: root.activeCase.length > 0 ? `Case: ${root.activeCase}` : "No active case"
                    font.bold: true
                    font.pointSize: Appearance.font.size.smaller * 0.9
                    color: Colours.palette.m3onSurface
                }

                Item { Layout.fillWidth: true }

                TextButton {
                    text: "Hunt ↗"
                    type: TextButton.Filled
                    visible: root.activeCase.length > 0
                    onClicked: root.launchAgentInCase(root.selectedAgent)
                }

                TextButton {
                    text: "Triage"
                    type: TextButton.Tonal
                    onClicked: {
                        triageProc.running = true;
                    }
                }
            }
        }

        // 3. Running Sessions (Compact, Scrollable if many)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.tiny
            visible: root.sessionCount > 0

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: "ACTIVE SESSIONS (CLICK TO JUMP)"
                    font.pointSize: Appearance.font.size.smaller * 0.85
                    font.bold: true
                    color: Colours.palette.m3primary
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: root.sessionCount > 4 ? `scroll for ${root.sessionCount} total` : ""
                    font.pointSize: Appearance.font.size.smaller * 0.8
                    color: Colours.palette.m3outline
                }
            }

            StyledFlickable {
                Layout.fillWidth: true
                implicitHeight: Math.min(sessionsCol.implicitHeight, 140)
                contentWidth: width
                contentHeight: sessionsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sessionsCol
                    width: parent.width
                    spacing: Appearance.spacing.tiny

                    Repeater {
                        model: root.sessions

                        StyledRect {
                            id: sessCard
                            required property var modelData

                            Layout.fillWidth: true
                            radius: Appearance.rounding.small
                            color: cardMouse.containsMouse ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer
                            implicitHeight: cardLayout.implicitHeight + 8

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.focusSession(sessCard.modelData.pid)
                            }

                            RowLayout {
                                id: cardLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Appearance.padding.small
                                anchors.rightMargin: Appearance.padding.small
                                spacing: Appearance.spacing.small

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "terminal"
                                    color: Colours.palette.m3primary
                                    font.pointSize: Appearance.font.size.smaller
                                }

                                StyledText {
                                    text: sessCard.modelData.agent.toUpperCase()
                                    font.bold: true
                                    font.pointSize: Appearance.font.size.smaller * 0.95
                                    color: Colours.palette.m3primary
                                }

                                StyledText {
                                    text: `${sessCard.modelData.pid}`
                                    font.pointSize: Appearance.font.size.smaller * 0.85
                                    font.family: Appearance.font.family.mono
                                    color: Colours.palette.m3outline
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: sessCard.modelData.task || sessCard.modelData.cwd || ""
                                    font.pointSize: Appearance.font.size.smaller * 0.85
                                    elide: Text.ElideMiddle
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    text: "Jump ↗"
                                    font.pointSize: Appearance.font.size.smaller * 0.85
                                    font.bold: true
                                    color: cardMouse.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outline
                                }
                            }
                        }
                    }
                }
            }
        }

        // 4. Provider Selector Tabs (Full Width, Perfectly Proportioned)
        StyledRect {
            Layout.fillWidth: true
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainerLow
            implicitHeight: 38

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: Appearance.spacing.tiny

                Repeater {
                    model: [
                        { id: "claude", label: "Claude" },
                        { id: "codex", label: "Codex" },
                        { id: "antigravity", label: "Agy" },
                        { id: "opencode", label: "OpenCode" }
                    ]

                    TextButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: modelData.label
                        type: root.selectedAgent === modelData.id ? TextButton.Filled : TextButton.Text
                        onClicked: root.selectedAgent = modelData.id
                    }
                }
            }
        }

        // 5. Rate Limits (5h & 7d) for Selected Agent
        StyledRect {
            Layout.fillWidth: true
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainer
            implicitHeight: limitsLayout.implicitHeight + Appearance.padding.normal * 2

            ColumnLayout {
                id: limitsLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.normal
                spacing: Appearance.spacing.small

                // Provider Plan Hero
                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: (root.currentProvider?.name || root.selectedAgent).toUpperCase()
                        font.bold: true
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3onSurface
                    }

                    Item { Layout.fillWidth: true }

                    StyledRect {
                        radius: Appearance.rounding.small
                        color: Colours.palette.m3secondaryContainer
                        implicitHeight: tierText.implicitHeight + 4
                        implicitWidth: tierText.implicitWidth + 12

                        StyledText {
                            id: tierText
                            anchors.centerIn: parent
                            text: root.currentProvider?.tierLabel || "Active"
                            font.bold: true
                            font.pointSize: Appearance.font.size.smaller * 0.9
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }

                // Limits List (5h and 7d meters)
                Repeater {
                    model: root.currentProvider?.limits || []

                    ColumnLayout {
                        id: limitRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: limitRow.modelData.label || "Limit"
                                font.pointSize: Appearance.font.size.smaller
                                color: Colours.palette.m3onSurface
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: root.formatTimeRemaining(limitRow.modelData.resetsAt)
                                font.pointSize: Appearance.font.size.smaller * 0.85
                                color: Colours.palette.m3outline
                                visible: text.length > 0
                            }

                            StyledText {
                                text: root.formatPercent(limitRow.modelData.percent)
                                font.pointSize: Appearance.font.size.smaller
                                font.bold: true
                                color: {
                                    const p = limitRow.modelData.percent || 0;
                                    if (p >= 0.9) return Colours.palette.m3error;
                                    if (p >= 0.7) return Colours.palette.m3tertiary;
                                    return Colours.palette.m3primary;
                                }
                            }
                        }

                        // Meter track & fill
                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: Colours.palette.m3surfaceContainerHigh

                            StyledRect {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(4, parent.width * Math.min(1.0, Math.max(0.0, limitRow.modelData.percent || 0)))
                                radius: 4
                                color: {
                                    const p = limitRow.modelData.percent || 0;
                                    if (p >= 0.9) return Colours.palette.m3error;
                                    if (p >= 0.7) return Colours.palette.m3tertiary;
                                    return Colours.palette.m3primary;
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 250 }
                                }
                            }
                        }
                    }
                }

                // 7-Day Activity Mini-Bars
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: (root.currentProvider?.recentDays?.length || 0) > 0

                    StyledText {
                        text: "7-DAY ACTIVITY"
                        font.pointSize: Appearance.font.size.smaller * 0.85
                        font.bold: true
                        color: Colours.palette.m3outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.currentProvider?.recentDays || []

                            ColumnLayout {
                                id: dayCol
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 2

                                readonly property real maxCount: {
                                    let m = 1;
                                    for (const d of (root.currentProvider?.recentDays || [])) {
                                        if (d.messageCount > m) m = d.messageCount;
                                    }
                                    return m;
                                }

                                StyledRect {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    radius: 2
                                    color: Colours.palette.m3surfaceContainerHigh

                                    StyledRect {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: Math.max(2, parent.height * (dayCol.modelData.messageCount / dayCol.maxCount))
                                        radius: 2
                                        color: dayCol.index === 6 ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3primary, 0.45)
                                    }
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: dayCol.modelData.date.slice(5) // MM-DD
                                    font.pointSize: Appearance.font.size.smaller * 0.75
                                    color: dayCol.index === 6 ? Colours.palette.m3primary : Colours.palette.m3outline
                                }
                            }
                        }
                    }
                }
            }
        }

        // 6. Quick Launch Actions
        StyledRect {
            Layout.fillWidth: true
            radius: Appearance.rounding.normal
            color: Colours.palette.m3surfaceContainerLow
            implicitHeight: launchRow.implicitHeight + Appearance.padding.smaller * 2

            RowLayout {
                id: launchRow
                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                Repeater {
                    model: [
                        { name: "claude", label: "+ Claude" },
                        { name: "codex", label: "+ Codex" },
                        { name: "opencode", label: "+ OpenCode" },
                        { name: "antigravity", label: "+ Agy" }
                    ]

                    TextButton {
                        required property var modelData
                        text: modelData.label
                        type: TextButton.Tonal
                        onClicked: root.launchAgent(modelData.name)
                    }
                }
            }
        }
    }
}
