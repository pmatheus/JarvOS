pragma Singleton
pragma ComponentBehavior: Bound

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var entries: []

    function search(query: string): list<var> {
        if (query.length < 2)
            return [];

        const lowerQuery = query.toLowerCase();
        const results = [];

        for (const entry of root.entries) {
            const score = fuzzyMatch(entry.name.toLowerCase(), lowerQuery);
            if (score > 0)
                results.push({ entry, score });
        }

        results.sort((a, b) => b.score - a.score);
        return results.slice(0, 8).map(r => r.entry);
    }

    function fuzzyMatch(str: string, query: string): real {
        let qi = 0;
        let score = 0;
        let consecutive = 0;

        for (let i = 0; i < str.length && qi < query.length; i++) {
            if (str[i] === query[qi]) {
                qi++;
                consecutive++;
                score += consecutive;
                if (i === 0 || str[i - 1] === '/' || str[i - 1] === '.' || str[i - 1] === '-' || str[i - 1] === '_')
                    score += 3;
            } else {
                consecutive = 0;
            }
        }

        return qi === query.length ? score : 0;
    }

    Component.onCompleted: loadIndex()

    function loadIndex(): void {
        readProc.buffer = [];
        readProc.running = true;
    }

    FileView {
        id: indexFileView

        path: Qt.resolvedUrl(`file://${Quickshell.env("HOME")}/.cache/spotlight/index.txt`)
        watchChanges: true
        onFileChanged: {
            this.reload();
            reloadDebounce.restart();
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
        command: ["bash", "-c", "cat \"$HOME/.cache/spotlight/index.txt\" 2>/dev/null"]

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("[file] ")) {
                    const path = line.slice(7);
                    readProc.buffer.push({
                        path: path,
                        name: path.split("/").pop() || path,
                        isDir: false,
                        _type: "file"
                    });
                } else if (line.startsWith("[folder] ")) {
                    const path = line.slice(9).replace(/\/$/, "");
                    readProc.buffer.push({
                        path: path,
                        name: path.split("/").pop() || path,
                        isDir: true,
                        _type: "folder"
                    });
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.entries = readProc.buffer;
        }
    }
}
