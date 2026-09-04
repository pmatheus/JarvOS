.pragma library

// Hyprland device/option plumbing for services/Hypr.qml, replacing
// caelestia's HyprExtras/HyprDevices/HyprKeyboard. Requests go through the
// hyprctl CLI (j/devices, descriptions -j, keyword batches) instead of a
// raw socket; the parsers here are unit-tested against the real output
// shapes.

// hyprctl -j devices -> [{address, name, layout, activeKeymap, capsLock,
// numLock, main}]. The snake_case active_keymap is normalised to the
// camelCase the consumers already read.
function parseDevices(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    const keyboards = data && data.keyboards;
    if (!Array.isArray(keyboards))
        return [];
    return keyboards.map(kb => ({
        address: kb.address ?? "",
        name: kb.name ?? "",
        layout: kb.layout ?? "",
        activeKeymap: kb.active_keymap ?? "",
        capsLock: !!kb.capsLock,
        numLock: !!kb.numLock,
        main: !!kb.main
    }));
}

// hyprctl descriptions -j -> {"<option name>": <current value>}
function parseOptions(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return {};
    }
    if (!Array.isArray(data))
        return {};
    const options = {};
    for (const option of data)
        if (option && option.name !== undefined)
            options[option.name] = option.current;
    return options;
}

// "keyword <name> <value>" per option, values stringified.
function optionCommands(options) {
    const commands = [];
    for (const name in options)
        commands.push(`keyword ${name} ${options[name]}`);
    return commands;
}

// The [[BATCH]]-style request as hyprctl --batch expects it: commands
// joined with semicolons.
function batchRequest(commands) {
    return (commands ?? []).join(";");
}
