import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/session.js" as Session

TestCase {
    name: "Session"

    function test_prepare_for_sleep_true_means_sleep() {
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager PrepareForSleep (true,)"), "sleep");
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager PrepareForSleep (true)"), "sleep");
    }

    function test_prepare_for_sleep_false_is_a_wake_and_ignored() {
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager PrepareForSleep (false,)"), null);
    }

    function test_lock_signal() {
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager Lock ()"), "lock");
    }

    function test_unlock_signal_is_not_confused_with_lock() {
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager Unlock ()"), "unlock");
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager Lock ()"), "lock");
    }

    function test_unrelated_lines_are_ignored() {
        compare(Session.parse("Monitor is attached"), null);
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.login1.Manager ScheduleShutdown (s,)"), null);
        compare(Session.parse(""), null);
    }

    function test_properties_and_other_members_ignored() {
        compare(Session.parse("/org/freedesktop/login1: org.freedesktop.DBus.Properties PropertiesChanged (\"sa{sv}as\")"), null);
    }
}
