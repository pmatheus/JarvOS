import QtQuick
import Quickshell.Io

import "../../../utils/appdb.js" as Store

// App database, ported from caelestia's C++ AppDb. Not a singleton — the
// launcher and the control centre each hold one over a different entry
// filter. Frequencies persist as JSON through FileView (Quickshell has no
// SQL); the sort — favourites first, launch count descending, then
// locale-aware name — lives in utils/appdb.js and is unit-tested there.
// Entries are Quickshell DesktopEntry objects used directly: every member
// the old AppEntry wrapper exposed (id, name, comment, execString,
// startupClass, genericName, categories, keywords) is already on the
// native type, so there is no wrapper and no .entry indirection.
QtObject {
    id: root

    property string path: ""
    property var entries: []
    property list<string> favouriteApps: []
    property list<QtObject> apps: []

    property var _frequencies: ({})
    property bool _loaded: false

    onPathChanged: loadStore()
    onEntriesChanged: rebuildTimer.restart()
    onFavouriteAppsChanged: rebuild()

    Component.onCompleted: {
        if (!_loaded && root.path !== "")
            loadStore();
        else
            rebuild();
    }

    property FileView store: FileView {
        path: root.path
    }

    property Timer rebuildTimer: Timer {
        interval: 300
        onTriggered: root.rebuild()
    }

    function loadStore(): void {
        if (root.path === "")
            return;
        let parsed = {};
        try {
            parsed = Store.parse(store.text());
        } catch (e) {
            parsed = {};
        }
        root._frequencies = parsed;
        root._loaded = true;
        rebuild();
    }

    function rebuild(): void {
        root.apps = Store.sort(root.entries, root._frequencies, root.favouriteApps);
    }

    function incrementFrequency(id): void {
        Store.increment(root._frequencies, id);
        store.setText(JSON.stringify(root._frequencies));
        rebuild();
    }
}
