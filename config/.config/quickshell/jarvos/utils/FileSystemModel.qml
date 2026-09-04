import QtQuick
import QtQml.Models
import Quickshell.Io

import "filesystem.js" as FS

// Directory listing model, ported from caelestia's C++ FileSystemModel. A
// DelegateModel over the scanned entries: views bind it directly and their
// delegates receive each FileSystemEntry as modelData. `find` supplies the
// raw scan; all observable behaviour — the filter modes, hidden-file
// handling, relative paths and the dirs-first locale-aware sort — lives in
// filesystem.js and is unit-tested there. Directory changes are watched
// live with inotifywait when watchChanges is set (the default), debounced
// through rescanTimer.
DelegateModel {
    id: root

    // Mirrors filesystem.js's filter constants, which are the source of truth.
    enum Filter { NoFilter, Images, Files, Dirs }

    property string path: ""
    property bool recursive: false
    property int filter: 0
    property var nameFilters: []
    property bool sortReverse: false
    property bool showHidden: false
    property bool watchChanges: true

    // The current entries as a plain array, for consumers that index the
    // list directly (Wallpapers.list feeds the launcher searcher).
    property var entries: []

    model: root.entries

    property var _scanned: null

    onPathChanged: refresh()
    onRecursiveChanged: refresh()
    onFilterChanged: rebuild()
    onShowHiddenChanged: rebuild()
    onNameFiltersChanged: rebuild()
    onSortReverseChanged: rebuild()

    Component.onCompleted: {
        if (_scanned === null)
            refresh();
    }

    Process {
        id: findProc

        stdout: StdioCollector {
            onStreamFinished: {
                root._scanned = FS.parseFindOutput(text);
                root.rebuild();
            }
        }
    }

    Process {
        id: watchProc

        stdout: SplitParser {
            onRead: data => rescanTimer.restart()
        }
    }

    Timer {
        id: rescanTimer

        interval: 150
        onTriggered: root.refresh()
    }

    property Component entryComp: Component {
        FileSystemEntry {
        }
    }

    property Process findProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root._scanned = FS.parseFindOutput(text);
                root.rebuild();
            }
        }
    }

    property Process watchProc: Process {
        stdout: SplitParser {
            onRead: data => rescanTimer.restart()
        }
    }

    property Timer rescanTimer: Timer {
        interval: 150
        onTriggered: root.refresh()
    }

    function refresh(): void {
        restartWatcher();
        if (root.path === "") {
            _scanned = [];
            rebuild();
            return;
        }

        const args = ["find", "-L", root.path];
        if (!root.recursive)
            args.push("-maxdepth", "1");
        args.push("-printf", "%y\t%p\n");
        findProc.command = args;
        findProc.running = true;
    }

    function rebuild(): void {
        const specs = _scanned === null || root.path === "" ? [] : FS.buildEntries(_scanned, root.path, {
                    "filter": root.filter,
                    "showHidden": root.showHidden,
                    "sortReverse": root.sortReverse,
                    "nameFilters": root.nameFilters
                });

        const created = specs.map(spec => root.entryComp.createObject(root, {
                    "path": spec.path,
                    "relativePath": spec.relativePath,
                    "isDir": spec.isDir
                }));
        const old = root.entries;

        root.entries = created;
        for (const entry of old)
            entry.destroy();
    }

    function restartWatcher(): void {
        watchProc.running = false;
        if (!root.watchChanges || root.path === "")
            return;

        const args = ["inotifywait", "-m", "-q", "-q", "-e", "create,delete,moved_to,moved_from"];
        if (root.recursive)
            args.push("-r");
        args.push("--", root.path);
        watchProc.command = args;
        watchProc.running = true;
    }
}
