pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Live wallust palette (~/.cache/wallust/colors.json, regenerated on every
// wallpaper switch by applycolor.sh) - the actual 16-color ANSI palette
// wallust produces, as opposed to SMColors' separate material-colors
// pipeline. For anything meant to read as "terminal/code themed" (like the
// clipboard panel's code previews), this is the palette that should drive
// it so those colors track the current wallpaper the same way a themed
// terminal would.
Singleton {
    id: root

    // Index-matched to color0..color15 (standard ANSI roles: 1 red, 2 green,
    // 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white, 8-15 bright variants).
    property list<color> colors: ["#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888", "#888888"]

    readonly property color red: colors[1]
    readonly property color green: colors[2]
    readonly property color yellow: colors[3]
    readonly property color magenta: colors[5]
    readonly property color cyan: colors[6]
    readonly property color brightBlack: colors[8]

    FileView {
        path: Qt.resolvedUrl(`${Directories.genericCache}/wallust/colors.json`)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                const cols = root.colors.slice()
                for (let i = 0; i < 16; i++) {
                    const c = data.colors?.[`color${i}`]
                    if (c) cols[i] = c
                }
                root.colors = cols
            } catch (e) {}
        }
    }
}
