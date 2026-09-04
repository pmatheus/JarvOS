.pragma library

// File listing logic for utils/FileSystemModel.qml, ported from
// caelestia-shell's FileSystemModel/FileSystemEntry
// (plugin/src/Caelestia/Models/filesystemmodel.cpp). The QML component only
// runs `find` and feeds the output through here; everything observable —
// filtering, hidden files, image matching, relative paths and the
// dirs-first sort — lives in this file so it can be unit-tested.

// Filter mode ints, the single source of truth. FileSystemModel's QML enum
// mirrors these values and passes its filter property straight through to
// buildEntries.
var NoFilter = 0;
var Images = 1;
var Files = 2;
var Dirs = 3;

// QFileInfo::baseName: everything before the first dot, except that a
// leading dot marks a hidden file and is kept. "archive.tar.gz" ->
// "archive", "README" -> "README", ".bashrc" -> ".bashrc".
function baseName(name) {
    const start = name.startsWith(".") ? 1 : 0;
    const dot = name.indexOf(".", start);
    return dot === -1 ? name : name.slice(0, dot);
}

// QDir::relativeFilePath: path of the entry relative to the model dir,
// walking up with ".." when the entry lies outside it.
function relativePathOf(filePath, dir) {
    const cleanDir = dir.endsWith("/") ? dir.slice(0, -1) : dir;
    if (filePath.startsWith(cleanDir + "/"))
        return filePath.slice(cleanDir.length + 1);

    const dirParts = cleanDir.split("/").filter(p => p !== "");
    const fileParts = filePath.split("/").filter(p => p !== "");
    let common = 0;
    while (common < dirParts.length && common < fileParts.length && dirParts[common] === fileParts[common])
        common++;
    return "../".repeat(dirParts.length - common) + fileParts.slice(common).join("/");
}

// QDir::nameFilters glob: "recording_*.mp4" style, anchored to the whole
// name, case-sensitive, regex specials matched literally.
function nameFilterMatches(name, filters) {
    if (!filters || filters.length === 0)
        return true;
    return filters.some(filter => {
        const rx = filter
            .split(/([*?])/)
            .map(part => part === "*" ? ".*" : part === "?" ? "." : part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
            .join("");
        return new RegExp("^" + rx + "$").test(name);
    });
}

// Image extensions supersets QImageReader's supported formats; matching is
// extension-based (the content sniffing of QImageReader::canRead is not
// available to pure QML) and case-insensitive.
const _imageExtensions = new Set(["avif", "bmp", "gif", "heic", "heif", "ico", "j2k", "jp2", "jpeg", "jpg", "pfm", "pgm", "png", "ppm", "qoi", "svg", "svgz", "tif", "tiff", "webp", "xbm", "xpm"]);

function isImagePath(name) {
    const dot = name.lastIndexOf(".");
    if (dot === -1)
        return false;
    return _imageExtensions.has(name.slice(dot + 1).toLowerCase());
}

// find -printf "%y\t%p\n" output -> [{type, path}]
function parseFindOutput(text) {
    const lines = [];
    for (const line of text.split("\n")) {
        if (!line)
            continue;
        const tab = line.indexOf("\t");
        if (tab === -1)
            continue;
        lines.push({
            type: line.slice(0, tab),
            path: line.slice(tab + 1)
        });
    }
    return lines;
}

// Raw scan lines -> filtered and sorted entry specs carrying the full
// FileSystemEntry surface. Dirs sort first (last when sortReverse), ties
// broken by locale-aware comparison of the relative path, mirroring
// FileSystemModel::compareEntries.
function buildEntries(scanLines, dir, opts) {
    const filter = opts.filter || NoFilter;
    const showHidden = !!opts.showHidden;
    const sortReverse = !!opts.sortReverse;

    const filtered = [];
    for (const line of scanLines) {
        const isDir = line.type === "d";
        const name = line.path.slice(line.path.lastIndexOf("/") + 1);

        if (!showHidden && name.startsWith("."))
            continue;
        if (filter === Images && (!isDir && !isImagePath(name) || isDir))
            continue;
        if (filter === Files && isDir)
            continue;
        if (filter === Dirs && !isDir)
            continue;
        if (!nameFilterMatches(name, opts.nameFilters))
            continue;

        filtered.push({
            path: line.path,
            name: name,
            baseName: baseName(name),
            relativePath: relativePathOf(line.path, dir),
            isDir: isDir
        });
    }

    filtered.sort((a, b) => {
        if (a.isDir !== b.isDir)
            return a.isDir !== sortReverse ? -1 : 1;
        const cmp = a.relativePath.localeCompare(b.relativePath);
        return sortReverse ? -cmp : cmp;
    });
    return filtered;
}
