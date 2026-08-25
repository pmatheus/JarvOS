import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/files.js" as Files

TestCase {
    name: "Files"

    function test_toLocalFile_strips_the_scheme() {
        compare(Files.toLocalFile("file:///home/user/a.png"), "/home/user/a.png");
    }

    function test_toLocalFile_passes_through_a_bare_path() {
        compare(Files.toLocalFile("/home/user/a.png"), "/home/user/a.png");
    }

    function test_toLocalFile_of_empty_is_empty() {
        compare(Files.toLocalFile(""), "");
    }

    function test_toLocalFile_decodes_percent_escapes() {
        compare(Files.toLocalFile("file:///home/user/my%20walls/a%20b.png"), "/home/user/my walls/a b.png");
    }

    function test_urlForPath_adds_the_scheme() {
        compare(Files.urlForPath("/home/user/a.png"), "file:///home/user/a.png");
    }

    function test_urlForPath_leaves_an_existing_url_alone() {
        compare(Files.urlForPath("file:///home/user/a.png"), "file:///home/user/a.png");
    }

    function test_urlForPath_of_empty_is_empty() {
        compare(Files.urlForPath(""), "");
    }

    function test_urlForPath_encodes_spaces() {
        compare(Files.urlForPath("/home/user/my walls/a b.png"), "file:///home/user/my%20walls/a%20b.png");
    }

    function test_urlForPath_encodes_a_hash() {
        // encodeURI leaves # alone, which would turn the rest of the name into
        // a URL fragment and silently truncate the path.
        compare(Files.urlForPath("/home/user/walls/a#1.png"), "file:///home/user/walls/a%231.png");
    }

    function test_a_path_with_spaces_round_trips() {
        const p = "/home/user/my wallpapers/a b.png";
        compare(Files.toLocalFile(Files.urlForPath(p)), p);
    }

    function test_a_path_with_punctuation_round_trips() {
        const p = "/home/user/walls/a#1 & b?c.png";
        compare(Files.toLocalFile(Files.urlForPath(p)), p);
    }
}
