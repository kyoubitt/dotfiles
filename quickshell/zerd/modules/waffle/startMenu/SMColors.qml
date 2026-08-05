pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Colors are generated into a plain JSON cache file (not this file) by
// applycolor.sh's apply_startmenu(), from the same material_colors.scss the
// bar uses, so a wallpaper switch only triggers a lightweight data reload
// here instead of a full shell reload, and stays in sync with the bar
// (previously wallust-sourced here, which used a different color-extraction
// algorithm than the bar and drifted out of sync with it).
Singleton {
    id: root

    readonly property color bg: colorsAdapter.bg
    readonly property color fg: colorsAdapter.fg
    readonly property color accent: colorsAdapter.accent

    FileView {
        // Deliberately outside the quickshell config directory: Quickshell
        // watches config .qml files and does a full engine reload on change,
        // which used to fire on every wallpaper switch when wallust wrote
        // straight into this directory as a .qml file.
        path: `${Directories.genericCache}/material/startmenu-colors.json`
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: colorsAdapter
            property color bg: "#07080C"
            property color fg: "#AEAFB3"
            property color accent: "#9DBFE4"
        }
    }
}
