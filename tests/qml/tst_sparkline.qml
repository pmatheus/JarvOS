import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/sparkline.js" as SG

TestCase {
    name: "Sparkline"

    // --- paint gating -----------------------------------------------------

    function test_nothing_draws_when_both_lines_have_fewer_than_two_points() {
        compare(SG.shouldDraw(0, 0), false);
        compare(SG.shouldDraw(1, 0), false);
        compare(SG.shouldDraw(0, 1), false);
        compare(SG.shouldDraw(1, 1), false);
    }

    function test_line_with_two_or_more_points_draws() {
        compare(SG.shouldDraw(2, 0), true);
        compare(SG.shouldDraw(0, 2), true);
        compare(SG.shouldDraw(1, 5), true);
    }

    // --- x geometry -------------------------------------------------------

    function test_step_x_divides_width_over_history_minus_one() {
        compare(SG.stepX(100, 5), 25);
        compare(SG.stepX(300, 31), 10);
    }

    function test_start_x_puts_newest_point_one_step_beyond_right_edge_when_slide_is_zero() {
        // startX = w - (len-1)*step - step*slide + step
        // newest x = startX + (len-1)*step = w + step*(1 - slide)
        const start = SG.startX(100, 5, 5, 0);
        compare(start, 25);
        const newestX = start + 4 * SG.stepX(100, 5);
        compare(newestX, 125);
    }

    function test_slide_progress_of_one_brings_newest_point_to_the_right_edge() {
        const start = SG.startX(100, 5, 5, 1);
        const newestX = start + 4 * SG.stepX(100, 5);
        compare(newestX, 100);
    }

    function test_start_x_is_independent_of_count_beyond_the_history_window() {
        // The original never clamps: a full buffer (historyLength + 1 points)
        // starts exactly at the left edge and slides left of the item as the
        // slide animates, the oldest point clipped away.
        compare(SG.startX(100, 6, 5, 0), 0);
        verify(SG.startX(100, 6, 5, 0.5) < 0);
        verify(SG.startX(90, 6, 5, 0.5) < 0);
    }

    // --- y mapping --------------------------------------------------------

    function test_y_maps_max_value_to_the_top_and_zero_to_the_bottom() {
        const pts = SG.linePoints([0, 50], 100, 100, 50, 5, 0);
        compare(pts[0].y, 100);
        compare(pts[1].y, 0);
    }

    function test_values_above_max_value_overflow_unclamped_like_the_original() {
        const pts = SG.linePoints([100], 100, 100, 50, 5, 0);
        compare(pts[0].y, -100);
    }

    function test_x_positions_advance_one_step_per_point_from_start() {
        const pts = SG.linePoints([1, 2, 3], 100, 100, 3, 5, 0);
        const start = SG.startX(100, 3, 5, 0);
        compare(pts[0].x, start);
        compare(pts[1].x, start + 25);
        compare(pts[2].x, start + 50);
    }

    // --- fill geometry ----------------------------------------------------

    function test_fill_closes_under_the_line_down_to_the_bottom() {
        const pts = SG.linePoints([10, 20], 100, 100, 100, 5, 0);
        const fill = SG.fillPoints(pts, 100);
        compare(fill.length, 4);
        // bottom-right corner sits under the last point
        compare(fill[2].x, pts[1].x);
        compare(fill[2].y, 100);
        // bottom-left corner sits under the first point, then the path closes
        compare(fill[3].x, pts[0].x);
        compare(fill[3].y, 100);
    }

    function test_fill_of_a_degenerate_line_is_empty() {
        compare(SG.fillPoints([], 100).length, 0);
        compare(SG.fillPoints([{x: 0, y: 0}], 100).length, 0);
    }
}
