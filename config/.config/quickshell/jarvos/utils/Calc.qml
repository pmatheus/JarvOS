pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "calc.js" as C

Singleton {
    id: root

    // Process is asynchronous, so the result arrives through a callback instead
    // of a return value.
    //
    // Every call gets its own process and nothing is shared between callers:
    // the launcher evaluates on each keystroke while the clipboard copy fires
    // once, and a shared process would let the fast path cancel the slow one.
    // Coalescing belongs to the caller that actually has a hot path.
    function evaluate(expr: string, printExpr: bool, callback: var): void {
        // No argv means the expression is blank and qalc must not be spawned;
        // see calc.js for why that would hang rather than fail.
        const cmd = C.command(expr);
        if (!cmd) {
            if (callback)
                callback("");
            return;
        }

        procComp.createObject(root, {
            command: cmd,
            printExpr: printExpr,
            callback: callback
        }).running = true;
    }

    Component {
        id: procComp

        Process {
            id: proc

            property bool printExpr
            property var callback
            property bool done

            function finish(out: string): void {
                if (proc.done)
                    return;
                proc.done = true;
                if (proc.callback)
                    proc.callback(C.parse(out, proc.printExpr));
                proc.destroy();
            }

            stdout: StdioCollector {
                onStreamFinished: proc.finish(text)
            }

            // A process that never produced a stream — qalc missing, or killed
            // before it wrote — would otherwise leak the object and never call
            // back.
            onExited: proc.finish("")
        }
    }
}
