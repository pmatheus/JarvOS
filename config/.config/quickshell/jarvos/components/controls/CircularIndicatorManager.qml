import QtQuick

import "../../utils/circularindicator.js" as CI

// Indeterminate circular-indicator state machine, ported from caelestia's
// C++ CircularIndicatorManager. The indicator's NumberAnimation drives
// progress 0..1; the fractions and rotation here are derived from the pure
// maths in utils/circularindicator.js, which is unit-tested. Property
// names are the contract with CircularIndicator.qml.
QtObject {
    id: root

    // Mirrors circularindicator.js's type constants, the source of truth.
    enum IndeterminateAnimationType {
        Advance,
        Retreat
    }

    readonly property real startFraction: _state.startFraction
    readonly property real endFraction: _state.endFraction
    readonly property real rotation: _state.rotation
    readonly property real duration: CI.duration(indeterminateAnimationType)
    readonly property real completeEndDuration: CI.completeEndDuration(indeterminateAnimationType)

    property int indeterminateAnimationType: 0
    property real progress: 0
    property real completeEndProgress: 0

    property var _state: CI.update(0, 0, indeterminateAnimationType)

    onProgressChanged: refresh()
    onIndeterminateAnimationTypeChanged: refresh()
    onCompleteEndProgressChanged: refresh()

    function refresh(): void {
        _state = CI.update(progress, completeEndProgress, indeterminateAnimationType);
    }
}
