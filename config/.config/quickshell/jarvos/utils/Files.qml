pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Window
import "files.js" as F

Singleton {
    id: root

    // Two components grabbing to one path race: saving truncates the file
    // before writing it, so whatever reads in the gap gets nothing. Anything
    // that grabs repeatedly takes a number from here once, and deletes the file
    // it named when it goes away.
    property int scratchCount: 0

    function toLocalFile(path: var): string {
        return F.toLocalFile(path);
    }

    function urlForPath(path: var): string {
        return F.urlForPath(path);
    }

    // Process is asynchronous, so success arrives through a callback instead of
    // a return value.
    function copyFile(source: var, dest: var, callback: var): void {
        exec(["cp", "-f", "--", F.toLocalFile(source), F.toLocalFile(dest)], callback);
    }

    function deleteFile(path: var, callback: var): void {
        exec(["rm", "--", F.toLocalFile(path)], callback);
    }

    // rect and callback occupy the same argument slot: one call site crops, the
    // other does not, and both are kept working the way they were.
    function saveItem(item: Item, dest: var, rect: var, callback: var): void {
        if (typeof rect === "function") {
            callback = rect;
            rect = undefined;
        }

        const path = F.toLocalFile(dest);
        const dpr = item.Window?.window?.devicePixelRatio ?? 1;

        item.grabToImage(result => {
            if (!rect) {
                root.write(() => result.saveToFile(path), path, callback);
                return;
            }

            // grabToImage takes no crop rect, so the grab is re-rendered through
            // a clipping wrapper sized to the rect and grabbed again. The wrapper
            // never shows: an item's own scene graph node is grabbable whether or
            // not the item is visible.
            const wrapper = cropComp.createObject(item, {
                grab: result,
                crop: Qt.rect(rect.x, rect.y, rect.width, rect.height),
                full: Qt.size(item.width, item.height)
            });
            wrapper.grabToImage(cropped => {
                root.write(() => cropped.saveToFile(path), path, callback);
                wrapper.destroy();
            }, Qt.size(Math.round(rect.width * dpr), Math.round(rect.height * dpr)));
        }, Qt.size(Math.round(item.width * dpr), Math.round(item.height * dpr)));
    }

    // saveToFile will not create the directory it writes into, and the
    // notification image cache lives under one that need not exist yet.
    function write(save: var, path: string, callback: var): void {
        const slash = path.lastIndexOf("/");
        if (slash <= 0) {
            save();
            if (callback)
                callback(path);
            return;
        }

        exec(["mkdir", "-p", "--", path.slice(0, slash)], () => {
            save();
            if (callback)
                callback(path);
        });
    }

    function exec(command: var, callback: var): void {
        procComp.createObject(root, {
            command: command,
            callback: callback
        }).running = true;
    }

    Component {
        id: procComp

        Process {
            property var callback

            onExited: code => {
                if (callback)
                    callback(code === 0);
                destroy();
            }
        }
    }

    Component {
        id: cropComp

        Item {
            id: wrapper

            // Holds the grab result alive: its url is only valid while it is.
            required property var grab
            required property rect crop
            required property size full

            visible: false
            clip: true
            width: crop.width
            height: crop.height

            Image {
                x: -wrapper.crop.x
                y: -wrapper.crop.y
                width: wrapper.full.width
                height: wrapper.full.height
                source: wrapper.grab.url
                asynchronous: false
                cache: false
            }
        }
    }
}
