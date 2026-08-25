.pragma library

// Path and URL conversion, kept out of QML so it can be unit-tested.
// Percent-encoding matters: wallpaper directories routinely have spaces, and
// encodeURI leaves # and ? alone, which would turn the rest of a filename into
// a URL fragment or query and silently truncate the path.

function toLocalFile(url) {
    if (!url)
        return "";
    const s = url.toString();
    if (!s.startsWith("file://"))
        return s;
    return decodeURIComponent(s.slice("file://".length));
}

function urlForPath(path) {
    if (!path)
        return "";
    const s = path.toString();
    if (s.includes("://"))
        return s;
    return "file://" + s.split("/").map(seg => encodeURIComponent(seg)).join("/");
}
