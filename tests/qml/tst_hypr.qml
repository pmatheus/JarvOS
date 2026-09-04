import QtQuick
import QtTest
import "../../config/.config/quickshell/jarvos/utils/hypr.js" as HP

TestCase {
    name: "Hypr"

    readonly property string devicesJson: JSON.stringify({
            mice: [],
            keyboards: [{
                    address: "0x1",
                    name: "kb-main",
                    layout: "us",
                    active_keymap: "English (US)",
                    capsLock: false,
                    numLock: true,
                    main: true
                }, {
                    address: "0x2",
                    name: "kb-second",
                    layout: "de",
                    active_keymap: "German",
                    capsLock: true,
                    numLock: false,
                    main: false
                }],
            tablets: [],
            touch: [],
            switches: []
        })

    function test_parse_devices_normalises_fields() {
        const keyboards = HP.parseDevices(devicesJson);
        compare(keyboards.length, 2);
        compare(keyboards[0].activeKeymap, "English (US)");
        compare(keyboards[1].capsLock, true);
        compare(keyboards[0].address, "0x1");
        compare(keyboards[0].main, true);
    }

    function test_main_keyboard_lookup() {
        const keyboards = HP.parseDevices(devicesJson);
        const main = keyboards.find(kb => kb.main);
        compare(main.name, "kb-main");
    }

    function test_parse_devices_of_garbage_is_empty() {
        compare(HP.parseDevices("not json").length, 0);
        compare(HP.parseDevices("").length, 0);
        compare(HP.parseDevices('{"keyboards": "not-a-list"}').length, 0);
    }

    function test_parse_options_maps_name_to_current() {
        const json = JSON.stringify([{
                name: "general:border_size",
                current: 2
            }, {
                name: "decoration:rounding",
                current: 15
            }]);
        const options = HP.parseOptions(json);
        compare(options["general:border_size"], 2);
        compare(options["decoration:rounding"], 15);
    }

    function test_parse_options_of_garbage_is_empty() {
        compare(Object.keys(HP.parseOptions("nope")).length, 0);
        compare(Object.keys(HP.parseOptions("")).length, 0);
    }

    function test_option_commands_stringify_values() {
        const commands = HP.optionCommands({
                "animations:enabled": 0,
                "decoration:rounding": 15,
                "general:allow_tearing": 1
            });
        compare(commands.length, 3);
        verify(commands.includes("keyword animations:enabled 0"));
        verify(commands.includes("keyword decoration:rounding 15"));
        verify(commands.includes("keyword general:allow_tearing 1"));
    }

    function test_batch_request_joins_with_semicolons() {
        compare(HP.batchRequest(["keyword a 1", "keyword b 2"]), "keyword a 1;keyword b 2");
        compare(HP.batchRequest([]), "");
    }
}
