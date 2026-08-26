import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/colour.js" as Colour

TestCase {
    name: "Colour"

    function rgb(r, g, b) {
        return {
            r: r,
            g: g,
            b: b
        };
    }

    function test_luminance_of_black_is_zero() {
        compare(Colour.luminance(0, 0, 0), 0);
    }

    function test_luminance_of_white_is_one() {
        fuzzyCompare(Colour.luminance(1, 1, 1), 1, 0.001);
    }

    function test_green_reads_brighter_than_blue() {
        // Perceptual weighting, not a plain average — a mid green must come
        // out brighter than a mid blue or every surface tint downstream shifts.
        verify(Colour.luminance(0, 0.5, 0) > Colour.luminance(0, 0, 0.5));
    }

    function test_luminance_squares_the_channels_before_weighting() {
        // Pins the exact expression the plugin used: sqrt of the Rec. 601
        // weighted sum of squares, which is also Colours.qml's getLuminance.
        // A linear Rec. 601 average would give 0.2935 here and a linear
        // Rec. 709 one 0.3576 — both would retint every layered surface.
        fuzzyCompare(Colour.luminance(0, 0.5, 0), 0.38308, 0.0001);
    }

    function test_mean_luminance_of_nothing_is_zero() {
        compare(Colour.meanLuminance([]), 0);
    }

    function test_mean_luminance_averages_luminance_not_colour() {
        // The plugin averaged each pixel's luminance. Averaging the colours
        // first and taking one luminance gives 0.3213 for these two, so this
        // catches the cheaper implementation.
        fuzzyCompare(Colour.meanLuminance([rgb(1, 0, 0), rgb(0, 0, 1)]), 0.44222, 0.0001);
    }

    function test_dominant_of_an_empty_list_is_null() {
        compare(Colour.dominant([]), null);
    }

    function test_dominant_is_the_most_common_colour_not_the_first() {
        const got = Colour.dominant([rgb(1, 0, 0), rgb(0, 1, 0), rgb(0, 1, 0)]);
        compare(got.g, 1);
        compare(got.r, 0);
    }

    function test_dominant_groups_colours_that_differ_below_the_mask() {
        // The plugin binned on the top five bits of each channel, so shades a
        // median-cut palette splits apart still count as one colour. Here two
        // near-identical reds must outvote two distinguishable greens.
        const red = rgb(1, 0, 0);
        const got = Colour.dominant([red, rgb(0xf8 / 255, 0, 0), rgb(0, 1, 0), rgb(0, 0xf0 / 255, 0)]);
        compare(got.r, red.r);
        compare(got.g, 0);
    }

    function test_dominant_returns_the_first_colour_of_the_winning_bin() {
        const first = rgb(1, 0, 0);
        const got = Colour.dominant([first, rgb(0xf9 / 255, 0, 0)]);
        compare(got.r, first.r);
    }
}
