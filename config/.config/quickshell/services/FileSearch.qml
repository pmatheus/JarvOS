pragma Singleton
pragma ComponentBehavior: Bound

import "root:/modules/common/functions/fuzzysort.js" as Fuzzy
import "root:/modules/common"
import "root:/"
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []
    readonly property var preparedEntries: entries.map(e => ({
        name: Fuzzy.prepare(e.name),
        path: e.path,
        isDir: e.isDir
    }))

    function fuzzyQuery(search: string): var {
        if (search.length < 2) return [];
        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name",
            limit: 10
        }).map(r => ({
            path: r.obj.path,
            name: r.obj.path.split("/").pop() || r.obj.path,
            isDir: r.obj.isDir
        }));
    }

    Component.onCompleted: loadIndex()

    function loadIndex() {
        readProc.buffer = []
        readProc.running = true
    }

    // Watch the index file for changes and auto-reload
    FileView {
        id: indexFileView
        path: Qt.resolvedUrl(`file://${Quickshell.env("HOME")}/.cache/spotlight/index.txt`)
        watchChanges: true
        onFileChanged: {
            this.reload()
            reloadDebounce.restart()
        }
    }

    Timer {
        id: reloadDebounce
        interval: 500
        onTriggered: root.loadIndex()
    }

    Process {
        id: readProc
        property var buffer: []

        command: ["bash", "-c", "cat \"$HOME/.cache/spotlight/index.txt\""]

        stdout: SplitParser {
            onRead: (line) => {
                if (line.startsWith("[file] ")) {
                    const path = line.slice(7);
                    readProc.buffer.push({
                        path: path,
                        name: path.split("/").pop() || path,
                        isDir: false
                    });
                } else if (line.startsWith("[folder] ")) {
                    const path = line.slice(9).replace(/\/$/, "");
                    readProc.buffer.push({
                        path: path,
                        name: path.split("/").pop() || path,
                        isDir: true
                    });
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.entries = readProc.buffer;
            } else {
                console.error("[FileSearch] Failed to load index with code", exitCode);
            }
        }
    }
}
