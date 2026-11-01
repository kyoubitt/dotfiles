pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Stand-in for iNiR's screen-frame singleton. There is no frame band here:
// the dock floats, so the band and safe insets are zero and the edge comes
// from config.
Singleton {
    readonly property string dockEdge: {
        const edge = String(Config.options?.iris?.dock?.edge ?? "bottom")
        return ["top", "bottom", "left", "right"].includes(edge) ? edge : "bottom"
    }
    readonly property real band: 0
    readonly property bool framed: false
    function safeInset(edge: string): real { return 0 }
}
