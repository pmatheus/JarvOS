import QtQuick

// Refcount helper, ported from caelestia's C++ ServiceRef. Setting
// `service` refs it for as long as this component is alive; the service
// exposes ref(sender)/unref(sender) and starts or stops its underlying
// work when the first ref arrives or the last one leaves. Services here
// are plain QtObjects (see Audio.qml's cava), so the lifetime contract is
// QML-reachable, unlike the C++ original whose ref/unref were not
// invokable.
QtObject {
    id: root

    property var service
    property var _held: null

    onServiceChanged: {
        if (root._held === root.service)
            return;
        if (root._held)
            root._held.unref(root);
        root._held = root.service ?? null;
        if (root._held)
            root._held.ref(root);
    }

    Component.onCompleted: {
        if (root.service) {
            root._held = root.service;
            root._held.ref(root);
        }
    }

    Component.onDestruction: {
        if (root._held)
            root._held.unref(root);
    }
}
