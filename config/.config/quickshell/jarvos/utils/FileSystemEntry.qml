import QtQuick

import "filesystem.js" as FS

// One listed file or directory. Created only by FileSystemModel; path,
// relativePath and isDir are known at scan time, name and baseName derive
// from the path (QFileInfo::baseName semantics, see filesystem.js).
QtObject {
    required property string path
    required property string relativePath
    required property bool isDir

    readonly property string name: path.slice(path.lastIndexOf("/") + 1)
    readonly property string baseName: FS.baseName(name)
}
