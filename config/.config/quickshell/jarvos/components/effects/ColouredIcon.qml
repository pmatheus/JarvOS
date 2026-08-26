pragma ComponentBehavior: Bound

import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Window
import "../../utils/colour.js" as Colour

IconImage {
    id: root

    required property color colour

    // ColorQuantizer only reads local files — it has no sourceItem and hands
    // its URL straight to QImage — so the rendered icon has to be written out
    // before it can be analysed. The name is this instance's alone rather than
    // derived from the icon, because two icons sharing a name overwrite each
    // other's file while the other is reading it.
    property string grabPath

    // grabToImage needs a visible window and a real size, and none of those
    // arrive in a fixed order, so every input retriggers and the timer collapses
    // the burst. The plugin did the same waiting internally.
    readonly property bool grabbable: layer.enabled && status === Image.Ready && width > 0
        && height > 0 && (Window.window?.visible ?? false)

    function analyse(): void {
        if (!grabbable || !grabPath)
            return;

        Files.saveItem(root, grabPath, () => {
            // Cleared first: the path is stable across re-grabs, and writing a
            // URL a ColorQuantizer already holds is a no-op, so without this a
            // second grab of the same icon would never be re-analysed.
            quantiser.source = "";
            quantiser.source = Files.urlForPath(root.grabPath);
        });
    }

    asynchronous: true

    layer.enabled: true
    layer.effect: Colouriser {
        // Black is what the plugin reported before its first analysis landed.
        sourceColor: quantiser.colors.length > 0 ? Colour.dominant(quantiser.colors) : "black"
        colorizationColor: root.colour
    }

    onGrabbableChanged: if (grabbable)
        debounce.restart()
    onGrabPathChanged: if (grabbable)
        debounce.restart()

    Component.onCompleted: grabPath = `${Paths.imagecache}/icons/${Files.scratchCount++}.png`
    Component.onDestruction: if (grabPath)
        Files.deleteFile(grabPath)

    Timer {
        id: debounce

        interval: 50
        onTriggered: root.analyse()
    }

    // depth 5 was picked by measuring both implementations over eight real tray
    // icons rendered at bar size: hue comes out identical and lightness within
    // 0.028, where depth 3 collapses a whole icon onto one accent. Lightness is
    // all that matters — Colouriser reads nothing else off this colour.
    ColorQuantizer {
        id: quantiser

        depth: 5
        rescaleSize: 128
    }
}
