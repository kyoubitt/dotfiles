pragma Singleton

import QtQuick
import Quickshell

// iNiR pauses desktop-widget animation when the desktop can't be seen; here the
// wallpaper window already hides itself, so animation just stays on.
Singleton {
    readonly property bool widgetsActive: true
}
