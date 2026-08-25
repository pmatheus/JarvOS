import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var list
    readonly property string math: list.search.text.slice(`${Config.launcher.actionPrefix}calc `.length)

    // qalc runs out of process, so an answer lands after the keystroke that
    // asked for it. This holds the last one that arrived; the previous answer
    // stays on screen while the next runs, so typing never blanks the display.
    property string answer

    // At most one qalc at a time. A keystroke arriving while one runs is held
    // here and run on completion, so a burst of typing collapses to the final
    // expression instead of spawning a process per character.
    property bool evaluating
    property var pending

    onMathChanged: root.evaluate(math)
    Component.onCompleted: root.evaluate(math)

    function evaluate(expr: string): void {
        if (root.evaluating) {
            root.pending = expr;
            return;
        }

        if (!expr) {
            root.answer = "";
            return;
        }

        root.evaluating = true;
        Calc.evaluate(expr, true, res => {
            root.evaluating = false;

            // A superseded answer is never painted: showing it before the newer
            // one lands is exactly the flicker this avoids.
            if (root.pending === undefined)
                root.answer = res;
            else {
                const next = root.pending;
                root.pending = undefined;
                root.evaluate(next);
            }
        });
    }

    function onClicked(): void {
        Calc.evaluate(root.math, false, res => Quickshell.execDetached(["wl-copy", res]));
        root.list.visibilities.launcher = false;
    }

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.onClicked();
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger

        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: "function"
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            id: result

            color: {
                if (text.includes("error: ") || text.includes("warning: "))
                    return Colours.palette.m3error;
                if (!root.math)
                    return Colours.palette.m3onSurfaceVariant;
                return Colours.palette.m3onSurface;
            }

            text: root.math.length > 0 ? root.answer : qsTr("Type an expression to calculate")
            elide: Text.ElideLeft

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }

        StyledRect {
            color: Colours.palette.m3tertiary
            radius: Appearance.rounding.normal
            clip: true

            implicitWidth: (stateLayer.containsMouse ? label.implicitWidth + label.anchors.rightMargin : 0) + icon.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: Math.max(label.implicitHeight, icon.implicitHeight) + Appearance.padding.small * 2

            Layout.alignment: Qt.AlignVCenter

            StateLayer {
                id: stateLayer

                color: Colours.palette.m3onTertiary

                function onClicked(): void {
                    Quickshell.execDetached(["app2unit", "--", ...Config.general.apps.terminal, "fish", "-C", `exec qalc -i '${root.math}'`]);
                    root.list.visibilities.launcher = false;
                }
            }

            StyledText {
                id: label

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: icon.left
                anchors.rightMargin: Appearance.spacing.small

                text: qsTr("Open in calculator")
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.normal

                opacity: stateLayer.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {}
                }
            }

            MaterialIcon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal

                text: "open_in_new"
                color: Colours.palette.m3onTertiary
                font.pointSize: Appearance.font.size.large
            }

            Behavior on implicitWidth {
                Anim {
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }
        }
    }
}
