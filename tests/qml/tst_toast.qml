import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/toast.js" as Queue

TestCase {
    name: "Toast"

    // --- normalization ------------------------------------------------------

    function test_icon_defaults_by_type_when_empty() {
        compare(Queue.create("t", "m", "", Queue.Info, 5000).icon, "info");
        compare(Queue.create("t", "m", "", Queue.Success, 5000).icon, "check_circle_unread");
        compare(Queue.create("t", "m", "", Queue.Warning, 5000).icon, "warning");
        compare(Queue.create("t", "m", "", Queue.Error, 5000).icon, "error");
    }

    function test_explicit_icon_is_kept() {
        compare(Queue.create("t", "m", "vpn_key", Queue.Info, 5000).icon, "vpn_key");
    }

    function test_timeout_defaults_by_type_when_not_positive() {
        compare(Queue.create("t", "m", "i", Queue.Warning, 0).timeout, 7000);
        compare(Queue.create("t", "m", "i", Queue.Error, -1).timeout, 10000);
        compare(Queue.create("t", "m", "i", Queue.Info, 0).timeout, 5000);
        compare(Queue.create("t", "m", "i", Queue.Success, 0).timeout, 5000);
    }

    function test_explicit_positive_timeout_is_kept() {
        compare(Queue.create("t", "m", "i", Queue.Info, 1234).timeout, 1234);
    }

    // --- queue: adding and closing ------------------------------------------

    function test_new_toasts_go_to_the_front() {
        const queue = [];
        const first = Queue.create("first", "m", "i", Queue.Info, 5000);
        const second = Queue.create("second", "m", "i", Queue.Info, 5000);
        Queue.push(queue, first);
        Queue.push(queue, second);
        compare(queue.length, 2);
        compare(queue[0].title, "second");
        compare(queue[1].title, "first");
    }

    function test_close_marks_closed_and_finishes_when_unlocked() {
        const queue = [];
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        Queue.push(queue, toast);
        compare(toast.closed, false);
        compare(Queue.close(toast), true);
        compare(toast.closed, true);
    }

    function test_closing_one_leaves_the_others() {
        const queue = [];
        const a = Queue.create("a", "m", "i", Queue.Info, 5000);
        const b = Queue.create("b", "m", "i", Queue.Info, 5000);
        Queue.push(queue, a);
        Queue.push(queue, b);
        Queue.close(a);
        Queue.remove(queue, a);
        compare(queue.length, 1);
        compare(queue[0].title, "b");
        compare(b.closed, false);
    }

    // --- lock / unlock -------------------------------------------------------

    function test_locked_toast_closes_but_does_not_finish() {
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        Queue.lock(toast, "hover");
        compare(Queue.close(toast), false);
        compare(toast.closed, true);
    }

    function test_unlocking_lets_a_closed_toast_finish() {
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        Queue.lock(toast, "hover");
        Queue.close(toast);
        compare(Queue.unlock(toast, "hover"), true);
    }

    function test_unlocking_an_open_toast_does_not_finish_it() {
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        Queue.lock(toast, "hover");
        compare(Queue.unlock(toast, "hover"), false);
        compare(toast.closed, false);
    }

    function test_multiple_locks_hold_until_the_last_one_releases() {
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        Queue.lock(toast, "one");
        Queue.lock(toast, "two");
        Queue.lock(toast, "one"); // duplicate lock is a no-op
        Queue.close(toast);
        compare(Queue.unlock(toast, "one"), false);
        compare(Queue.unlock(toast, "one"), false);
        compare(Queue.unlock(toast, "two"), true);
    }

    function test_unknown_unlock_is_a_noop() {
        const toast = Queue.create("t", "m", "i", Queue.Info, 5000);
        compare(Queue.unlock(toast, "never-locked"), false);
    }

    // --- removal -------------------------------------------------------------

    function test_remove_only_removes_the_matching_toast() {
        const queue = [];
        const a = Queue.create("a", "m", "i", Queue.Info, 5000);
        const b = Queue.create("b", "m", "i", Queue.Info, 5000);
        Queue.push(queue, a);
        Queue.push(queue, b);
        Queue.remove(queue, a);
        compare(queue.length, 1);
        compare(queue[0].title, "b");
        Queue.remove(queue, a); // already gone: no-op
        compare(queue.length, 1);
    }
}
