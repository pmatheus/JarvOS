import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/circularbuffer.js" as CB

TestCase {
    name: "CircularBuffer"

    function test_empty_buffer() {
        const buf = CB.create(5);
        compare(CB.count(buf), 0);
        compare(CB.maximum(buf), 0);
        compare(CB.values(buf).length, 0);
        compare(CB.at(buf, 0), 0);
    }

    function test_count_before_buffer_fills() {
        const buf = CB.create(5);
        CB.push(buf, 10);
        compare(CB.count(buf), 1);
        compare(CB.maximum(buf), 10);
        compare(CB.at(buf, 0), 10);

        CB.push(buf, 25);
        compare(CB.count(buf), 2);
        compare(CB.maximum(buf), 25);
        compare(CB.at(buf, 0), 10);
        compare(CB.at(buf, 1), 25);
    }

    function test_eviction_past_capacity() {
        const buf = CB.create(3);
        CB.push(buf, 1);
        CB.push(buf, 2);
        CB.push(buf, 3);
        compare(CB.count(buf), 3);
        compare(CB.values(buf), [1, 2, 3]);

        // Push 4, evicting 1
        CB.push(buf, 4);
        compare(CB.count(buf), 3);
        compare(CB.values(buf), [2, 3, 4]);
        compare(CB.at(buf, 0), 2);
        compare(CB.at(buf, 1), 3);
        compare(CB.at(buf, 2), 4);
    }

    function test_maximum_over_retained_window_only() {
        const buf = CB.create(3);
        CB.push(buf, 100);
        CB.push(buf, 10);
        CB.push(buf, 20);
        compare(CB.maximum(buf), 100);

        // Evict 100 by pushing 30
        CB.push(buf, 30);
        compare(CB.maximum(buf), 30);

        CB.push(buf, 15);
        compare(CB.maximum(buf), 30);

        CB.push(buf, 5);
        // Window is now [30, 15, 5], max is 30
        compare(CB.maximum(buf), 30);

        CB.push(buf, 8);
        // Window is now [15, 5, 8], max is 15 (30 evicted)
        compare(CB.maximum(buf), 15);
    }

    function test_pushing_smaller_value_leaves_maximum_correct_after_largest_evicted() {
        const buf = CB.create(3);
        CB.push(buf, 50); // initial largest
        CB.push(buf, 20);
        CB.push(buf, 30);
        compare(CB.maximum(buf), 50);

        // Push 10 (not largest, 10 < 30), evicting 50
        // Window is now [20, 30, 10], max must be 30
        CB.push(buf, 10);
        compare(CB.maximum(buf), 30);
    }

    function test_clear_resets_buffer() {
        const buf = CB.create(3);
        CB.push(buf, 10);
        CB.push(buf, 20);
        CB.clear(buf);
        compare(CB.count(buf), 0);
        compare(CB.maximum(buf), 0);
        compare(CB.values(buf).length, 0);
    }

    function test_set_capacity_trims_excess() {
        const buf = CB.create(5);
        CB.push(buf, 1);
        CB.push(buf, 2);
        CB.push(buf, 3);
        CB.push(buf, 4);
        CB.setCapacity(buf, 2);
        compare(CB.count(buf), 2);
        compare(CB.values(buf), [3, 4]);
        compare(CB.maximum(buf), 4);
    }
}
