import Quickshell.Io

JsonObject {
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}
    property Padding padding: Padding {}
    property FontStuff font: FontStuff {}
    property Anim anim: Anim {}
    property Transparency transparency: Transparency {}

    component Rounding: JsonObject {
        property real scale: 1
        property int small: 12 * scale
        property int normal: 17 * scale
        property int large: 25 * scale
        property int full: 1000 * scale
    }

    component Spacing: JsonObject {
        property real scale: 1
        property int small: 7 * scale
        property int smaller: 10 * scale
        property int normal: 12 * scale
        property int larger: 15 * scale
        property int large: 20 * scale
    }

    component Padding: JsonObject {
        property real scale: 1
        property int small: 5 * scale
        property int smaller: 7 * scale
        property int normal: 10 * scale
        property int larger: 12 * scale
        property int large: 15 * scale
    }

    component FontFamily: JsonObject {
        property string sans: "Rubik"
        property string mono: "CaskaydiaCove NF"
        property string material: "Material Symbols Rounded"
        property string clock: "Rubik"
    }

    component FontSize: JsonObject {
        property real scale: 1
        property int small: 11 * scale
        property int smaller: 12 * scale
        property int normal: 13 * scale
        property int larger: 15 * scale
        property int large: 18 * scale
        property int extraLarge: 28 * scale
    }

    component FontStuff: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
    }

    component AnimCurves: JsonObject {
        // Multi-segment emphasis: fast start, controlled settle
        property list<real> emphasized: [0.05, 0, 0.12, 0.12, 0.16, 0.55, 0.20, 0.88, 0.25, 1, 1, 1]
        // Quick launch — aggressive start
        property list<real> emphasizedAccel: [0.25, 0, 0.7, 0.1, 1, 1]
        // Strong decel — Apple-style fast start, gentle land
        property list<real> emphasizedDecel: [0.05, 0.8, 0.08, 1, 1, 1]
        // Smooth default — slightly faster than M3
        property list<real> standard: [0.16, 0, 0, 1, 1, 1]
        property list<real> standardAccel: [0.25, 0, 1, 1, 1, 1]
        // Smooth decel — items rest gently
        property list<real> standardDecel: [0, 0, 0.05, 1, 1, 1]
        // Spatial: subtle overshoot (1.08) — snappy without wobble
        property list<real> expressiveFastSpatial: [0.22, 1.08, 0.36, 1, 1, 1]
        // Spatial default: barely perceptible overshoot (1.04) — energy without bounce
        property list<real> expressiveDefaultSpatial: [0.20, 1.04, 0.36, 1, 1, 1]
        // Effects: symmetric ease for opacity/color
        property list<real> expressiveEffects: [0.25, 0.8, 0.25, 1, 1, 1]
    }

    component AnimDurations: JsonObject {
        property real scale: 1
        property int small: 130 * scale          // was 200 — micro-feedback
        property int normal: 260 * scale          // was 400 — standard interactions
        property int large: 380 * scale           // was 600 — significant transitions
        property int extraLarge: 600 * scale      // was 1000 — choreographed sequences
        property int expressiveFastSpatial: 220 * scale  // was 350 — quick spatial
        property int expressiveDefaultSpatial: 300 * scale  // was 500 — primary spatial
        property int expressiveEffects: 150 * scale      // was 200 — visual effects
    }

    component Anim: JsonObject {
        property real mediaGifSpeedAdjustment: 300
        property real sessionGifSpeed: 0.7
        property AnimCurves curves: AnimCurves {}
        property AnimDurations durations: AnimDurations {}
    }

    component Transparency: JsonObject {
        property bool enabled: false
        property real base: 0.85
        property real layers: 0.4
    }
}
