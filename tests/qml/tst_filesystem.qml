import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/filesystem.js" as FS

TestCase {
    name: "FileSystem"

    // The model's QML enum mirrors these FS constants and passes its filter
    // property straight through, so tests pin the same ints the JS uses.
    readonly property int noFilter: FS.NoFilter
    readonly property int images: FS.Images
    readonly property int files: FS.Files
    readonly property int dirs: FS.Dirs

    // --- baseName (QFileInfo::baseName semantics) ---------------------------

    function test_base_name_stops_at_the_first_dot() {
        compare(FS.baseName("archive.tar.gz"), "archive");
    }

    function test_base_name_of_a_file_with_no_extension_is_the_whole_name() {
        compare(FS.baseName("README"), "README");
    }

    function test_base_name_keeps_the_leading_dot_of_hidden_files() {
        compare(FS.baseName(".bashrc"), ".bashrc");
    }

    function test_base_name_of_recording_names() {
        compare(FS.baseName("recording_20260904_10-30-00.mp4"), "recording_20260904_10-30-00");
    }

    function test_base_name_with_trailing_dot_is_empty_suffix() {
        compare(FS.baseName("file."), "file");
    }

    // --- relativePath (QDir::relativeFilePath semantics) --------------------

    function test_relative_path_inside_the_dir() {
        compare(FS.relativePathOf("/walls/mountain.png", "/walls"), "mountain.png");
    }

    function test_relative_path_in_a_subdirectory() {
        compare(FS.relativePathOf("/walls/landscapes/peak.png", "/walls"), "landscapes/peak.png");
    }

    function test_relative_path_outside_the_dir_walks_up() {
        compare(FS.relativePathOf("/other/other.png", "/walls/landscapes"), "../../other/other.png");
    }

    function test_relative_path_tolerates_a_trailing_slash_on_the_dir() {
        compare(FS.relativePathOf("/walls/a.png", "/walls/"), "a.png");
    }

    // --- name filters (QDir::nameFilters glob semantics) ---------------------

    function test_name_filter_star_matches_within_the_name_only() {
        verify(FS.nameFilterMatches("recording_20260904.mp4", ["recording_*.mp4"]));
        verify(!FS.nameFilterMatches("xrecording_20260904.mp4", ["recording_*.mp4"]));
        verify(!FS.nameFilterMatches("recording_20260904.mp4.bak", ["recording_*.mp4"]));
    }

    function test_name_filter_question_mark_matches_exactly_one_char() {
        verify(FS.nameFilterMatches("file1.txt", ["file?.txt"]));
        verify(!FS.nameFilterMatches("file10.txt", ["file?.txt"]));
    }

    function test_name_filter_escapes_regex_specials() {
        verify(FS.nameFilterMatches("file[1].txt", ["file[1].txt"]));
    }

    function test_name_filter_any_of_several_filters() {
        verify(FS.nameFilterMatches("a.png", ["*.jpg", "*.png"]));
        verify(FS.nameFilterMatches("b.jpg", ["*.jpg", "*.png"]));
        verify(!FS.nameFilterMatches("c.txt", ["*.jpg", "*.png"]));
    }

    function test_empty_name_filters_match_everything() {
        verify(FS.nameFilterMatches("anything.at.all", []));
    }

    // --- image filter -------------------------------------------------------

    function test_image_filter_matches_common_image_extensions_case_insensitively() {
        verify(FS.isImagePath("photo.png"));
        verify(FS.isImagePath("photo.PNG"));
        verify(FS.isImagePath("IMG_1234.JPEG"));
        verify(FS.isImagePath("art.webp"));
        verify(FS.isImagePath("vector.svg"));
        verify(FS.isImagePath("photo.avif"));
    }

    function test_image_filter_rejects_non_images() {
        verify(!FS.isImagePath("video.mp4"));
        verify(!FS.isImagePath("notes.txt"));
        verify(!FS.isImagePath("archive.tar.gz"));
        verify(!FS.isImagePath("noextension"));
    }

    // --- buildEntries: filter, relativePath, sort ---------------------------

    readonly property var scanLines: [
        { type: "f", path: "/walls/zebra.png" },
        { type: "d", path: "/walls/subdir" },
        { type: "f", path: "/walls/apple.jpg" },
        { type: "f", path: "/walls/.hidden.png" },
        { type: "f", path: "/walls/video.mp4" }
    ]

    function test_no_filter_lists_dirs_and_files_hidden_excluded() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: noFilter, showHidden: false, sortReverse: false });
        compare(entries.length, 4);
        // dirs first, then locale-aware by relativePath
        compare(entries[0].path, "/walls/subdir");
        compare(entries[1].path, "/walls/apple.jpg");
        compare(entries[2].path, "/walls/video.mp4");
        compare(entries[3].path, "/walls/zebra.png");
    }

    function test_images_filter_keeps_only_image_files() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: images, showHidden: false, sortReverse: false });
        compare(entries.length, 2);
        compare(entries[0].path, "/walls/apple.jpg");
        compare(entries[1].path, "/walls/zebra.png");
    }

    function test_files_filter_keeps_only_files() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: files, showHidden: false, sortReverse: false });
        verify(entries.every(e => !e.isDir));
        compare(entries.length, 3);
    }

    function test_dirs_filter_keeps_only_dirs() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: dirs, showHidden: false, sortReverse: false });
        compare(entries.length, 1);
        compare(entries[0].path, "/walls/subdir");
        verify(entries[0].isDir);
    }

    function test_show_hidden_includes_dotfiles() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: noFilter, showHidden: true, sortReverse: false });
        compare(entries.length, 5);
        // dirs still sort first; the hidden file sorts before the other files
        compare(entries[0].path, "/walls/subdir");
        compare(entries[1].path, "/walls/.hidden.png");
    }

    function test_sort_reverse_puts_dirs_last_and_reverses_names() {
        const entries = FS.buildEntries(scanLines, "/walls", { filter: noFilter, showHidden: false, sortReverse: true });
        compare(entries[0].path, "/walls/zebra.png");
        compare(entries[3].path, "/walls/subdir");
    }

    function test_entries_carry_the_full_surface() {
        const entries = FS.buildEntries([{ type: "f", path: "/walls/recording_20260904_10-30-00.mp4" }], "/walls", { filter: noFilter, showHidden: false, sortReverse: false });
        const e = entries[0];
        compare(e.path, "/walls/recording_20260904_10-30-00.mp4");
        compare(e.name, "recording_20260904_10-30-00.mp4");
        compare(e.baseName, "recording_20260904_10-30-00");
        compare(e.relativePath, "recording_20260904_10-30-00.mp4");
        compare(e.isDir, false);
    }

    function test_recursive_scan_paths_get_subdir_relative_paths() {
        const entries = FS.buildEntries([
            { type: "f", path: "/walls/landscapes/peak.png" },
            { type: "f", path: "/walls/a.png" }
        ], "/walls", { filter: noFilter, showHidden: false, sortReverse: false });
        compare(entries[0].relativePath, "a.png");
        compare(entries[1].relativePath, "landscapes/peak.png");
    }

    function test_parse_of_find_output_lines() {
        const lines = FS.parseFindOutput("f\t/walls/a.png\nd\t/walls/subdir\n");
        compare(lines.length, 2);
        compare(lines[0].type, "f");
        compare(lines[0].path, "/walls/a.png");
        compare(lines[1].type, "d");
        compare(lines[1].path, "/walls/subdir");
    }
}
