import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/cava.js" as Cava

TestCase {
    name: "Cava"

    function test_frame_parses_to_normalized_values() {
        compare(Cava.parseFrame("0 50 100 25 0 0", 100), [0, 0.5, 1, 0.25, 0, 0]);
    }

    function test_frame_with_extra_whitespace() {
        compare(Cava.parseFrame("  10   20  30  ", 100), [0.1, 0.2, 0.3]);
    }

    function test_empty_and_malformed_lines_are_null() {
        compare(Cava.parseFrame("", 100), null);
        compare(Cava.parseFrame("   ", 100), null);
        compare(Cava.parseFrame("0 x 2", 100), null);
    }

    function test_negative_values_are_rejected() {
        compare(Cava.parseFrame("-5 10", 100), null);
    }

    function test_other_max_range_scales() {
        compare(Cava.parseFrame("500 1000", 1000), [0.5, 1]);
    }

    function test_partial_frames_are_rejected() {
        // cava emits one value per configured bar; a short frame is a glitch
        compare(Cava.parseFrame("1 2 3", 100, 4), null);
    }

    function test_exact_length_passes() {
        compare(Cava.parseFrame("1 2 3 4", 100, 4), [0.01, 0.02, 0.03, 0.04]);
    }
}
