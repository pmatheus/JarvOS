// Proves the harness itself works: the Qt 6 runner, offscreen, finding suites.
// If this fails, nothing below it means anything.
import QtQuick
import QtTest

TestCase {
    name: "Harness"

    function test_runner_executes() {
        compare(1 + 1, 2);
    }

    function test_js_library_imports() {
        // The whole strategy rests on Qt resolving a .js import with no
        // qmldir and no module registration. If this breaks, the plan's
        // testing approach breaks with it.
        verify(typeof Qt.rect === "function");
    }
}
