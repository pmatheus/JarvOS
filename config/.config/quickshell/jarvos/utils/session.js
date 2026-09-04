.pragma library

// Logind signal parsing for services/Session.qml. gdbus monitor prints one
// line per signal: "<path>: <interface> <Member> (<args>)". Only three
// members matter — PrepareForSleep with a true argument (about to sleep;
// false is a wake and is ignored), Lock and Unlock. Everything else,
// including property changes and other Manager members, is noise.

function parse(line) {
    if (!line)
        return null;
    const match = /Manager\s+(\w+)\s*\(([^)]*)\)/.exec(line);
    if (!match)
        return null;
    const member = match[1];
    if (member === "PrepareForSleep")
        return /\btrue\b/.test(match[2] ?? "") ? "sleep" : null;
    if (member === "Lock")
        return "lock";
    if (member === "Unlock")
        return "unlock";
    return null;
}
