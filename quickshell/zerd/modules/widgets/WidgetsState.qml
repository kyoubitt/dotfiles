pragma Singleton

import QtQuick
import Quickshell.Io

// Toggle state for the widgets panel, driven from the niri keybind via
// `qs -c zerd ipc call widgetsPanel toggle`. Kept beside the panel rather
// than in GlobalStates because this module can't see that singleton.
QtObject {
    id: root
    property bool hidden: false
    // 12h vs 24h, shared by the clock and the weather card's sun times.
    property bool twelveHour: false

    readonly property IpcHandler ipc: IpcHandler {
        target: "widgetsPanel"

        function toggle(): void { root.hidden = !root.hidden }
        function show(): void { root.hidden = false }
        function hide(): void { root.hidden = true }
    }
}
