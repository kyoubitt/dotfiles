pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Colours for the visualizer widget. iNiR's own CavaTheme derives them from the
// cover art and its media stack; here they come from the wallust palette.
Singleton {
    readonly property var visualizerColors: [
        WallustTheme.accent,
        WallustColors.cyan,
        WallustColors.green,
        WallustColors.magenta,
    ]
}
