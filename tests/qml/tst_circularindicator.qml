import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/circularindicator.js" as CI

TestCase {
    name: "CircularIndicator"

    // --- easing curve (Material standard: cubic-bezier(0.4, 0, 0.2, 1)) -----

    function test_easing_endpoints() {
        compare(CI.ease(0), 0);
        compare(CI.ease(1), 1);
    }

    function test_easing_is_monotonic_and_in_range() {
        let prev = -1;
        for (let i = 0; i <= 20; ++i) {
            const t = i / 20;
            const v = CI.ease(t);
            verify(v >= prev - 1e-9, "non-decreasing at t=" + t);
            verify(v >= 0 && v <= 1, "in range at t=" + t);
            prev = v;
        }
    }

    function test_easing_fast_out_slow_in_rises_quickly_early() {
        // reference values for cubic-bezier(0.4, 0, 0.2, 1)
        verify(Math.abs(CI.ease(0.5) - 0.7756) < 0.01);
        verify(Math.abs(CI.ease(0.75) - 0.9594) < 0.01);
    }

    function test_easing_clamps_out_of_range_input() {
        compare(CI.ease(-0.5), 0);
        compare(CI.ease(1.5), 1);
    }

    // --- advance mode ---------------------------------------------------------

    function test_advance_at_zero_progress() {
        const s = CI.advance(0, 0);
        // tail offset -20deg, no cycles advanced yet
        compare(s.startFraction, -20 / 360);
        compare(s.endFraction, 0);
        compare(s.rotation, 0);
    }

    function test_advance_at_full_progress_all_cycles_complete() {
        const s = CI.advance(1, 0);
        // 1520deg constant + 4*250deg expanded and collapsed
        compare(s.startFraction, (1520 - 20 + 4 * 250) / 360);
        compare(s.endFraction, (1520 + 4 * 250) / 360);
    }

    function test_advance_gap_closes_on_complete_end() {
        const mid = CI.advance(0.5, 0);
        const done = CI.advance(0.5, 1);
        // start chases end until the gap is fully closed
        verify(Math.abs(done.startFraction - done.endFraction) < 1e-9);
        verify(mid.startFraction < mid.endFraction);
    }

    function test_advance_spans_multiple_turns() {
        const s = CI.advance(1, 0);
        verify(s.endFraction > 6, "over six turns of travel");
    }

    // --- retreat mode ----------------------------------------------------------

    function test_retreat_start_stays_at_zero() {
        compare(CI.retreat(0, 0).startFraction, 0);
        compare(CI.retreat(0.5, 0).startFraction, 0);
        compare(CI.retreat(1, 0).startFraction, 0);
    }

    function test_retreat_rotation_at_full_progress() {
        // 1080deg constant + 4 spins of 90deg each, all fully eased
        compare(CI.retreat(1, 0).rotation, 1080 + 4 * 90);
    }

    function test_retreat_rotation_scales_linearly_before_spins() {
        // at playtime 0.25*6000=1500ms the first spin is done, so 1080*0.25 + 90
        compare(CI.retreat(0.25, 0).rotation, 1080 * 0.25 + 90);
    }

    function test_retreat_end_fraction_stays_in_range() {
        for (let i = 0; i <= 10; ++i) {
            const s = CI.retreat(i / 10, 0);
            verify(s.endFraction >= 0.10 - 1e-9 && s.endFraction <= 0.87 + 1e-9);
        }
    }

    function test_retreat_grows_then_shrinks() {
        // early: growing toward the upper bound
        const quarter = CI.retreat(0.25, 0).endFraction;
        // by the end the shrink term pulls it back toward the lower bound
        const end = CI.retreat(1, 0).endFraction;
        verify(quarter > 0.5);
        verify(end < 0.3);
    }

    function test_retreat_complete_end_collapses_the_arc() {
        const done = CI.retreat(0.5, 1);
        compare(done.endFraction, 0);
    }

    // --- durations --------------------------------------------------------------

    function test_durations_by_type() {
        compare(CI.duration(0), 5400);
        compare(CI.completeEndDuration(0), 333);
        compare(CI.duration(1), 6000);
        compare(CI.completeEndDuration(1), 500);
    }
}
