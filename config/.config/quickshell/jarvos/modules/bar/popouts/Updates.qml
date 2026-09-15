pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var wrapper

    readonly property int contentWidth: 460
    implicitWidth: contentWidth
    implicitHeight: mainLayout.implicitHeight

    property bool showScheduler: false
    property bool showLogsInNormalView: false
    property var expandedGroups: ({ "pacman": true, "aur": true })

    function isGroupExpanded(id: string): bool {
        return !!root.expandedGroups[id];
    }

    function toggleGroup(id: string): void {
        const next = Object.assign({}, root.expandedGroups);
        next[id] = !next[id];
        root.expandedGroups = next;
    }

    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "updates" && !UpdateStatus.updating) {
                UpdateStatus.refreshIfStale(10 * 60 * 1000);
            }
        }
    }

    ColumnLayout {
        id: mainLayout

        width: root.contentWidth
        spacing: Appearance.spacing.normal

        // =====================================================================
        // VIEW 1: LIVE IN-PLUGIN UPDATE EXECUTION (TRANSPARENT, NO TERMINAL)
        // =====================================================================
        ColumnLayout {
            visible: UpdateStatus.updating
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            // Live Update Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: "sync"
                    color: Colours.palette.m3primary
                    font.pointSize: Appearance.font.size.large

                    RotationAnimation on rotation {
                        running: UpdateStatus.updating
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: qsTr("Atualização em Andamento")
                        font.bold: true
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: UpdateStatus.updatePhase || qsTr("Processando comandos...")
                        font.pointSize: Appearance.font.size.smaller
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: root.wrapper.close()
                }
            }

            // Current Activity Ticker
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: tickerLayout.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.small
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                RowLayout {
                    id: tickerLayout
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: "terminal"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: UpdateStatus.currentLogLine || qsTr("Aguardando saída...")
                        font.family: Appearance.font.family.mono
                        font.pointSize: Math.round(Appearance.font.size.smaller * 0.9)
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Live Output Console
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                radius: Appearance.rounding.small
                color: Colours.layer(Colours.palette.m3surfaceContainerLowest, 3)
                clip: true

                ListView {
                    id: liveLogList

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: 2
                    model: UpdateStatus.logLines
                    clip: true

                    delegate: StyledText {
                        required property string modelData

                        width: liveLogList.width
                        text: modelData
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Appearance.font.family.mono
                        font.pointSize: Math.round(Appearance.font.size.smaller * 0.85)
                        wrapMode: Text.WrapAnywhere
                    }

                    onCountChanged: {
                        Qt.callLater(() => {
                            liveLogList.positionViewAtEnd();
                        });
                    }
                }
            }

            // Status bar info
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("A execução continuará em segundo plano se você fechar este menu.")
                    font.pointSize: Appearance.font.size.smaller * 0.85
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                IconTextButton {
                    icon: "arrow_downward"
                    text: qsTr("Minimizar")
                    type: IconTextButton.Tonal
                    onClicked: root.wrapper.close()
                }
            }
        }

        // =====================================================================
        // VIEW 2: UPDATE COMPLETED VIEW
        // =====================================================================
        ColumnLayout {
            visible: !UpdateStatus.updating && UpdateStatus.updateFinished
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            // Finished Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    text: UpdateStatus.updateSuccess ? "check_circle" : "warning"
                    color: UpdateStatus.updateSuccess ? Colours.palette.m3success : Colours.palette.m3error
                    font.pointSize: Appearance.font.size.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: UpdateStatus.updateSuccess
                            ? qsTr("Atualização Concluída!")
                            : qsTr("Atualização Concluída com Avisos")
                        font.bold: true
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: UpdateStatus.updateSuccess
                            ? qsTr("O sistema está pronto e atualizado.")
                            : qsTr("Revise as mensagens geradas durante a execução.")
                        font.pointSize: Appearance.font.size.smaller
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: {
                        UpdateStatus.dismissUpdate();
                        root.wrapper.close();
                    }
                }
            }

            // Post-update Reboot Prompt (Immediate & Friendly)
            StyledRect {
                visible: UpdateStatus.rebootRequired
                Layout.fillWidth: true
                implicitHeight: finishedRebootLayout.implicitHeight + Appearance.padding.normal * 2
                radius: Appearance.rounding.normal
                color: Colours.palette.m3errorContainer

                ColumnLayout {
                    id: finishedRebootLayout
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            text: "restart_alt"
                            color: Colours.palette.m3onErrorContainer
                            font.pointSize: Appearance.font.size.large
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: qsTr("Reinício Recomendado")
                                font.bold: true
                                font.pointSize: Appearance.font.size.normal
                                color: Colours.palette.m3onErrorContainer
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: UpdateStatus.rebootReasons.length > 0
                                    ? UpdateStatus.rebootReasons.join("\n")
                                    : qsTr("O kernel foi atualizado para uma nova versão. Reinicie para aplicar as alterações com segurança.")
                                font.pointSize: Appearance.font.size.smaller
                                wrapMode: Text.Wrap
                                color: Colours.palette.m3onErrorContainer
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Item { Layout.fillWidth: true }

                        IconTextButton {
                            icon: root.showScheduler ? "expand_less" : "schedule"
                            text: root.showScheduler ? qsTr("Ocultar") : qsTr("Agendar")
                            type: IconTextButton.Tonal
                            onClicked: root.showScheduler = !root.showScheduler
                        }

                        IconTextButton {
                            icon: "restart_alt"
                            text: qsTr("Reiniciar Agora")
                            type: IconTextButton.Filled
                            activeColour: Colours.palette.m3error
                            inactiveColour: Colours.palette.m3error
                            activeOnColour: Colours.palette.m3onError
                            inactiveOnColour: Colours.palette.m3onError
                            onClicked: UpdateStatus.rebootNow()
                        }
                    }

                    // Schedule Quick Options
                    RowLayout {
                        visible: root.showScheduler
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        TextButton {
                            text: "+15m"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(15, "");
                                root.showScheduler = false;
                            }
                        }
                        TextButton {
                            text: "+30m"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(30, "");
                                root.showScheduler = false;
                            }
                        }
                        TextButton {
                            text: "+1h"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(60, "");
                                root.showScheduler = false;
                            }
                        }
                        TextButton {
                            text: "+2h"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(120, "");
                                root.showScheduler = false;
                            }
                        }
                        TextButton {
                            text: "23:00"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(0, "23:00");
                                root.showScheduler = false;
                            }
                        }
                        TextButton {
                            text: "03:00"
                            type: TextButton.Tonal
                            onClicked: {
                                UpdateStatus.scheduleReboot(0, "03:00");
                                root.showScheduler = false;
                            }
                        }
                    }
                }
            }

            // Final Output Logs (Collapsible)
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: Appearance.rounding.small
                color: Colours.layer(Colours.palette.m3surfaceContainerLowest, 3)
                clip: true

                ListView {
                    id: finishedLogList
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: 2
                    model: UpdateStatus.logLines
                    clip: true

                    delegate: StyledText {
                        required property string modelData
                        width: finishedLogList.width
                        text: modelData
                        color: Colours.palette.m3onSurfaceVariant
                        font.family: Appearance.font.family.mono
                        font.pointSize: Math.round(Appearance.font.size.smaller * 0.85)
                        wrapMode: Text.WrapAnywhere
                    }

                    Component.onCompleted: positionViewAtEnd()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                IconTextButton {
                    icon: "check"
                    text: qsTr("Concluir e Voltar")
                    type: IconTextButton.Filled
                    onClicked: UpdateStatus.dismissUpdate()
                }
            }
        }

        // =====================================================================
        // VIEW 3: STANDARD DISCOVERY VIEW (READY TO UPDATE OR REBOOT)
        // =====================================================================
        ColumnLayout {
            visible: !UpdateStatus.updating && !UpdateStatus.updateFinished
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            // 1. Header with Title, Status & Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: UpdateStatus.rebootRequired
                        ? "restart_alt"
                        : UpdateStatus.rebootScheduled
                            ? "schedule"
                            : "system_update_alt"

                    color: UpdateStatus.rebootRequired
                        ? Colours.palette.m3error
                        : UpdateStatus.rebootScheduled || UpdateStatus.total > 0
                            ? Colours.palette.m3tertiary
                            : Colours.palette.m3onSurfaceVariant

                    font.pointSize: Appearance.font.size.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: qsTr("Atualizações do Sistema")
                        font.bold: true
                        font.pointSize: Appearance.font.size.normal
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: UpdateStatus.running
                            ? qsTr("Verificando atualizações...")
                            : UpdateStatus.error !== ""
                                ? UpdateStatus.error
                                : UpdateStatus.rebootRequired
                                    ? qsTr("Reinício necessário após atualização")
                                    : UpdateStatus.rebootScheduled
                                        ? qsTr("Reinício agendado para as %1").arg(UpdateStatus.scheduledRebootTime)
                                        : UpdateStatus.total > 0
                                            ? qsTr("%1 atualização(ões) disponível(is)").arg(UpdateStatus.total)
                                            : qsTr("Sistema totalmente atualizado")
                        font.pointSize: Appearance.font.size.smaller
                        color: UpdateStatus.error !== ""
                            ? Colours.palette.m3error
                            : UpdateStatus.rebootRequired
                                ? Colours.palette.m3error
                                : Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "refresh"
                    disabled: UpdateStatus.running
                    type: IconButton.Tonal
                    onClicked: UpdateStatus.refresh()

                    RotationAnimation on rotation {
                        running: UpdateStatus.running
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "close"
                    type: IconButton.Text
                    onClicked: root.wrapper.close()
                }
            }

            // 2. Restart Banner (Required, Scheduled or Manual Scheduler)
            StyledRect {
                id: restartCard

                visible: UpdateStatus.rebootRequired || UpdateStatus.rebootScheduled || root.showScheduler
                Layout.fillWidth: true
                implicitHeight: restartLayout.implicitHeight + Appearance.padding.normal * 2

                radius: Appearance.rounding.normal
                color: UpdateStatus.rebootScheduled
                    ? Colours.palette.m3tertiaryContainer
                    : UpdateStatus.rebootRequired
                        ? Colours.palette.m3errorContainer
                        : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                Behavior on color {
                    ColorAnimation { duration: 250 }
                }

                ColumnLayout {
                    id: restartLayout

                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        MaterialIcon {
                            text: UpdateStatus.rebootScheduled
                                ? "schedule"
                                : UpdateStatus.rebootRequired
                                    ? "restart_alt"
                                    : "schedule"

                            color: UpdateStatus.rebootScheduled
                                ? Colours.palette.m3onTertiaryContainer
                                : UpdateStatus.rebootRequired
                                    ? Colours.palette.m3onErrorContainer
                                    : Colours.palette.m3primary

                            font.pointSize: Appearance.font.size.large
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: UpdateStatus.rebootScheduled
                                    ? qsTr("Reinício Agendado")
                                    : UpdateStatus.rebootRequired
                                        ? qsTr("Reinício Necessário")
                                        : qsTr("Programar Reinício")

                                font.bold: true
                                font.pointSize: Appearance.font.size.normal
                                color: UpdateStatus.rebootScheduled
                                    ? Colours.palette.m3onTertiaryContainer
                                    : UpdateStatus.rebootRequired
                                        ? Colours.palette.m3onErrorContainer
                                        : Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: UpdateStatus.rebootScheduled
                                    ? qsTr("O sistema será reiniciado às %1 (%2 min restantes).").arg(UpdateStatus.scheduledRebootTime).arg(Math.max(1, Math.ceil(UpdateStatus.scheduledRebootSecondsLeft / 60)))
                                    : UpdateStatus.rebootRequired
                                        ? (UpdateStatus.rebootReasons.length > 0
                                            ? UpdateStatus.rebootReasons.join("\n")
                                            : qsTr("O kernel ou serviços essenciais foram atualizados. Reinicie para aplicar as alterações com segurança."))
                                        : qsTr("Defina um horário para reiniciar o sistema com segurança.")

                                font.pointSize: Appearance.font.size.smaller
                                wrapMode: Text.Wrap
                                color: UpdateStatus.rebootScheduled
                                    ? Colours.palette.m3onTertiaryContainer
                                    : UpdateStatus.rebootRequired
                                        ? Colours.palette.m3onErrorContainer
                                        : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    // Action buttons for reboot
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Item { Layout.fillWidth: true }

                        IconTextButton {
                            visible: UpdateStatus.rebootScheduled
                            icon: "cancel"
                            text: qsTr("Cancelar Agendamento")
                            type: IconTextButton.Tonal
                            onClicked: UpdateStatus.cancelScheduledReboot()
                        }

                        IconTextButton {
                            visible: !UpdateStatus.rebootScheduled
                            icon: root.showScheduler ? "expand_less" : "schedule"
                            text: root.showScheduler ? qsTr("Ocultar Opções") : qsTr("Agendar Reinício")
                            type: IconTextButton.Tonal
                            onClicked: root.showScheduler = !root.showScheduler
                        }

                        IconTextButton {
                            icon: "restart_alt"
                            text: qsTr("Reiniciar Agora")
                            type: IconTextButton.Filled
                            activeColour: Colours.palette.m3error
                            inactiveColour: Colours.palette.m3error
                            activeOnColour: Colours.palette.m3onError
                            inactiveOnColour: Colours.palette.m3onError
                            onClicked: UpdateStatus.rebootNow()
                        }
                    }

                    // Schedule selection chips
                    ColumnLayout {
                        visible: root.showScheduler && !UpdateStatus.rebootScheduled
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        StyledText {
                            text: qsTr("Escolha o intervalo desejado:")
                            font.pointSize: Appearance.font.size.smaller
                            color: UpdateStatus.rebootRequired
                                ? Colours.palette.m3onErrorContainer
                                : Colours.palette.m3onSurfaceVariant
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.smaller

                            TextButton {
                                text: "+15m"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(15, "");
                                    root.showScheduler = false;
                                }
                            }

                            TextButton {
                                text: "+30m"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(30, "");
                                    root.showScheduler = false;
                                }
                            }

                            TextButton {
                                text: "+1h"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(60, "");
                                    root.showScheduler = false;
                                }
                            }

                            TextButton {
                                text: "+2h"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(120, "");
                                    root.showScheduler = false;
                                }
                            }

                            TextButton {
                                text: "23:00"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(0, "23:00");
                                    root.showScheduler = false;
                                }
                            }

                            TextButton {
                                text: "03:00"
                                type: TextButton.Tonal
                                onClicked: {
                                    UpdateStatus.scheduleReboot(0, "03:00");
                                    root.showScheduler = false;
                                }
                            }
                        }
                    }
                }
            }

            // 3. Main Update Triggers (In-Plugin, Transparent Execution)
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                IconTextButton {
                    Layout.fillWidth: true
                    icon: "system_update_alt"
                    text: qsTr("Atualizar Sistema")
                    type: IconTextButton.Filled
                    enabled: !(UpdateStatus.running || UpdateStatus.updating)
                    opacity: enabled ? 1.0 : 0.6
                    onClicked: UpdateStatus.startUpdate("--system")
                }

                IconTextButton {
                    Layout.fillWidth: true
                    icon: "code"
                    text: qsTr("Dev Tools")
                    type: IconTextButton.Tonal
                    enabled: !(UpdateStatus.running || UpdateStatus.updating)
                    opacity: enabled ? 1.0 : 0.6
                    onClicked: UpdateStatus.startUpdate("--devtools")
                }

                IconTextButton {
                    Layout.fillWidth: true
                    icon: "done_all"
                    text: qsTr("Tudo")
                    type: IconTextButton.Tonal
                    enabled: !(UpdateStatus.running || UpdateStatus.updating)
                    opacity: enabled ? 1.0 : 0.6
                    onClicked: UpdateStatus.startUpdate("--all")
                }

                IconButton {
                    visible: !UpdateStatus.rebootRequired && !UpdateStatus.rebootScheduled && !root.showScheduler
                    icon: "schedule"
                    type: IconButton.Tonal
                    onClicked: root.showScheduler = true
                }
            }

            // 4. Update Categories & Package List
            StyledFlickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(categoriesLayout.implicitHeight, 380)
                contentWidth: width
                contentHeight: categoriesLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: categoriesLayout

                    width: parent.width
                    spacing: Appearance.spacing.small

                    // If no updates and no reboot: display clean banner
                    StyledRect {
                        visible: UpdateStatus.total === 0 && !UpdateStatus.rebootRequired && !UpdateStatus.running
                        Layout.fillWidth: true
                        implicitHeight: noUpdatesRow.implicitHeight + Appearance.padding.large * 2
                        radius: Appearance.rounding.small
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                        RowLayout {
                            id: noUpdatesRow

                            anchors.fill: parent
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.normal

                            MaterialIcon {
                                text: "check_circle"
                                color: Colours.palette.m3success
                                font.pointSize: Appearance.font.size.large
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: qsTr("Tudo atualizado")
                                    font.bold: true
                                    font.pointSize: Appearance.font.size.normal
                                }

                                StyledText {
                                    text: qsTr("Nenhuma atualização pendente detectada.")
                                    font.pointSize: Appearance.font.size.smaller
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }

                    // List of groups
                    Repeater {
                        model: UpdateStatus.groups

                        delegate: StyledRect {
                            id: groupCard

                            required property var modelData

                            readonly property bool isExpanded: root.isGroupExpanded(modelData.id)

                            Layout.fillWidth: true
                            implicitHeight: groupContent.implicitHeight + Appearance.padding.normal * 2
                            radius: Appearance.rounding.small
                            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

                            ColumnLayout {
                                id: groupContent

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.normal
                                spacing: Appearance.spacing.smaller

                                // Group Header Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small

                                    MaterialIcon {
                                        text: groupCard.modelData.icon || "extension"
                                        color: groupCard.modelData.status === "updates"
                                            ? Colours.palette.m3tertiary
                                            : Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Appearance.font.size.normal
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: groupCard.modelData.name
                                        font.pointSize: Appearance.font.size.small
                                        font.weight: 500
                                        elide: Text.ElideRight
                                    }

                                    // Count badge
                                    StyledRect {
                                        implicitWidth: badgeText.implicitWidth + Appearance.padding.small * 2
                                        implicitHeight: badgeText.implicitHeight + Appearance.padding.small
                                        radius: Appearance.rounding.full
                                        color: groupCard.modelData.status === "updates"
                                            ? Colours.palette.m3tertiaryContainer
                                            : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                                        StyledText {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: groupCard.modelData.status === "updates"
                                                ? groupCard.modelData.count
                                                : groupCard.modelData.status
                                            color: groupCard.modelData.status === "updates"
                                                ? Colours.palette.m3onTertiaryContainer
                                                : Colours.palette.m3onSurfaceVariant
                                            font.pointSize: Math.round(Appearance.font.size.small * 0.85)
                                        }
                                    }

                                    IconButton {
                                        icon: groupCard.isExpanded ? "expand_less" : "expand_more"
                                        type: IconButton.Text
                                        onClicked: root.toggleGroup(groupCard.modelData.id)
                                    }
                                }

                                // Error text if present
                                StyledText {
                                    visible: groupCard.modelData.error && groupCard.modelData.error !== ""
                                    Layout.fillWidth: true
                                    text: groupCard.modelData.error
                                    color: Colours.palette.m3error
                                    wrapMode: Text.Wrap
                                    font.pointSize: Appearance.font.size.smaller
                                }

                                // Items preview
                                Repeater {
                                    visible: groupCard.isExpanded
                                    model: groupCard.modelData.items ? groupCard.modelData.items.slice(0, 40) : []

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
}
