.pragma library

// Favourites matching, launch-frequency storage and app ordering for
// modules/launcher/services/AppDb.qml, ported from caelestia's AppDb
// (plugin/src/Caelestia/Models/appdb.cpp). Frequencies live in a JSON file
// instead of SQLite — Quickshell has no SQL — and the sort is the same
// three-key contract: favourites first, then launch count descending, then
// locale-aware name.

// Compile the favourite patterns: a value already wrapped in ^...$ is used
// as a regex verbatim; anything else is escaped and anchored so a plain
// entry matches its id exactly. Invalid regexes are skipped, matching the
// C++ which warned and dropped them.
function compileFavourites(patterns) {
    const compiled = [];
    for (const pattern of patterns ?? []) {
        const source = pattern.startsWith("^") && pattern.endsWith("$") ? pattern : "^" + escape(pattern) + "$";
        try {
            compiled.push(new RegExp(source));
        } catch (e) {
            // invalid pattern: ignored, never fatal
        }
    }
    return compiled;
}

function escape(original) {
    return original.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function isFavourite(id, compiled) {
    for (const re of compiled)
        if (re.test(id))
            return true;
    return false;
}

function frequencyOf(frequencies, id) {
    const value = frequencies ? frequencies[id] : 0;
    return typeof value === "number" && isFinite(value) ? value : 0;
}

function increment(frequencies, id) {
    frequencies[id] = frequencyOf(frequencies, id) + 1;
}

// Sort a copy; the caller's list order is left alone. DesktopEntry objects
// carry id/name directly, so the comparator reads them off the entries.
function sort(apps, frequencies, favouritePatterns) {
    const compiled = compileFavourites(favouritePatterns);
    return apps.slice().sort((a, b) => {
        const aFav = isFavourite(a.id, compiled);
        const bFav = isFavourite(b.id, compiled);
        if (aFav !== bFav)
            return aFav ? -1 : 1;
        const aFreq = frequencyOf(frequencies, a.id);
        const bFreq = frequencyOf(frequencies, b.id);
        if (aFreq !== bFreq)
            return bFreq - aFreq;
        return String(a.name ?? "").localeCompare(String(b.name ?? ""));
    });
}

// Parse the stored frequencies; anything that is not a JSON object of
// finite numbers yields an empty store rather than a broken one.
function parse(text) {
    if (!text)
        return {};
    try {
        const value = JSON.parse(text);
        if (!value || typeof value !== "object" || Array.isArray(value))
            return {};
        const clean = {};
        for (const key in value)
            if (typeof value[key] === "number" && isFinite(value[key]))
                clean[key] = value[key];
        return clean;
    } catch (e) {
        return {};
    }
}
