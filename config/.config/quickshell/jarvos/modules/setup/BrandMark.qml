import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// The JarvOS mark: a `J` cut out of a rounded tile, the negative space being the
// letter. Drawn natively rather than loaded from brand/jarvos-mark.svg because
// that file expresses the cut-out with an SVG <mask>, which QtSvg does not
// implement — it would render as a plain filled tile. Geometry is the asset's,
// unchanged: 512 viewBox, corner radius 120/512, stroke width 58/512.
Item {
    id: root

    property color tileColour: Colours.palette.m3primary
    // The letter is a hole, so it must be painted in whatever sits behind the
    // tile — never a fixed colour.
    property color groundColour: Colours.tPalette.m3surface

    readonly property real design: 512

    implicitWidth: 64
    implicitHeight: 64

    StyledRect {
        anchors.fill: parent

        radius: root.width * 120 / root.design
        color: root.tileColour
    }

    Shape {
        anchors.centerIn: parent

        width: root.design
        height: root.design
        scale: root.width / root.design
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.groundColour
            strokeWidth: 58
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M332 139 V290 a76 76 0 0 1 -152 0"
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }
}
