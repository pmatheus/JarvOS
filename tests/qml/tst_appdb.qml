import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/appdb.js" as Store

TestCase {
    name: "AppDb"

    // --- favourite matching --------------------------------------------------

    function test_plain_pattern_matches_the_id_exactly() {
        const favs = Store.compileFavourites(["firefox"]);
        verify(Store.isFavourite("firefox", favs));
        verify(!Store.isFavourite("firefox-esr", favs));
        verify(!Store.isFavourite("Firefox", favs));
    }

    function test_explicit_regex_pattern_is_kept_as_a_regex() {
        const favs = Store.compileFavourites(["^web.*$"]);
        verify(Store.isFavourite("webstorm", favs));
        verify(Store.isFavourite("webcord", favs));
        verify(!Store.isFavourite("offwebstorm", favs));
    }

    function test_pattern_escapes_regex_specials() {
        const favs = Store.compileFavourites(["code [insiders]"]);
        verify(Store.isFavourite("code [insiders]", favs));
        verify(!Store.isFavourite("code insiders", favs));
    }

    function test_invalid_regex_is_ignored_not_fatal() {
        const favs = Store.compileFavourites(["^broken[", "ok"]);
        verify(Store.isFavourite("ok", favs));
        verify(!Store.isFavourite("anything", favs) || true); // must not throw
    }

    // --- ordering -------------------------------------------------------------

    function mk(id, name) {
        return {
            id: id,
            name: name
        };
    }

    function test_favourites_sort_first() {
        const sorted = Store.sort([mk("b", "Bapp"), mk("a", "Aapp"), mk("f", "Fav")], {}, ["f"]);
        compare(sorted[0].id, "f");
    }

    function test_frequency_descends_within_the_same_favourite_class() {
        const sorted = Store.sort([mk("low", "Low"), mk("high", "High"), mk("mid", "Mid")], {
            high: 9,
            mid: 5,
            low: 1
        }, []);
        compare(sorted[0].id, "high");
        compare(sorted[1].id, "mid");
        compare(sorted[2].id, "low");
    }

    function test_name_breaks_frequency_ties() {
        const sorted = Store.sort([mk("z", "Zebra"), mk("a", "Aardvark"), mk("m", "Mango")], {}, []);
        compare(sorted[0].id, "a");
        compare(sorted[1].id, "m");
        compare(sorted[2].id, "z");
    }

    function test_favourite_with_low_frequency_still_beats_plain_with_high() {
        const sorted = Store.sort([mk("busy", "Busy"), mk("fav", "Fav")], {
            busy: 50
        }, ["fav"]);
        compare(sorted[0].id, "fav");
    }

    function test_sort_does_not_mutate_the_input() {
        const apps = [mk("b", "Bapp", 5), mk("a", "Aapp", 5)];
        Store.sort(apps, {}, []);
        compare(apps[0].id, "b");
    }

    // --- frequency store ------------------------------------------------------

    function test_increment_initialises_at_one() {
        const freqs = {};
        Store.increment(freqs, "firefox");
        compare(freqs["firefox"], 1);
    }

    function test_increment_accumulates() {
        const freqs = {
            firefox: 4
        };
        Store.increment(freqs, "firefox");
        compare(freqs["firefox"], 5);
    }

    function test_frequency_defaults_to_zero_when_absent() {
        compare(Store.frequencyOf({}, "firefox"), 0);
        compare(Store.frequencyOf({
            firefox: 7
        }, "firefox"), 7);
    }

    function test_sort_uses_the_frequency_store() {
        const sorted = Store.sort([mk("cold", "Cold"), mk("hot", "Hot")], {
            hot: 3
        }, []);
        compare(sorted[0].id, "hot");
    }

    // --- serialisation round trip --------------------------------------------

    function test_store_round_trips_through_json() {
        const freqs = {
            firefox: 3,
            codex: 1
        };
        const back = Store.parse(JSON.stringify(freqs));
        compare(back["firefox"], 3);
        compare(back["codex"], 1);
    }

    function test_parse_of_garbage_is_an_empty_store() {
        compare(Object.keys(Store.parse("not json at all")).length, 0);
        compare(Object.keys(Store.parse("")).length, 0);
        compare(Object.keys(Store.parse('{"a": "not-a-number"}')).length, 0);
    }
}
