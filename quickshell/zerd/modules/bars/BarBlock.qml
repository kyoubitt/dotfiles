import QtQuick
import "ilya/bar"

// One bar block: his BarModule (pill plus face) for a block id, given the bar window facts the faces read.
Item {
    id: root

    property string blockId: ""
    property int barHeight: 34
    property var screen: null
    property bool revealed: true
    // strip and floating looks draw one plate behind everything, so the pills go flat
    property bool flat: false
    // inside a shared plate: no pill of its own
    property bool grouped: false

    readonly property alias module: mod
    width: mod.width
    height: barHeight
    visible: mod.moduleActive && mod.effectiveVisible && mod.width > 0

    QtObject {
        id: host
        readonly property var screen: root.screen
        readonly property int barHeight: root.barHeight
        readonly property string barPosition: "top"
        readonly property bool isRevealed: root.revealed
        readonly property bool isStartupReady: true
        readonly property bool isDataReady: true
        readonly property bool startupCascadeFinished: true
        readonly property bool positionChanging: false
        readonly property bool barConfigReady: true
        readonly property bool distinctPills: false
        readonly property real baseOffsetX: 0
        readonly property real baseOffsetY: 0
        readonly property real cornerRadius: 12
        readonly property bool visible: true
        readonly property real width: root.width
        readonly property real height: root.barHeight
        property bool fastPollerLoaded: false
        function s(v) { return Math.round(v) }
        function cs(v) { return Math.round(v) }
    }

    // TEMP DEBUG: where each block, its pill and its face sit in the window
    Timer {
        interval: 4000; running: root.visible; repeat: false
        onTriggered: {
            const b = root.mapToItem(null, 0, 0), m = mod.mapToItem(null, 0, 0), f = mod.faceItem ? mod.faceItem.mapToItem(null, 0, 0) : null
            console.log("BARDBG", root.blockId, "block y", b.y, "h", root.height, "| pill y", m.y, "h", mod.height, "| face y", f ? f.y : "-", "h", mod.faceItem ? mod.faceItem.height : "-", "grouped", root.grouped)
        }
    }

    BarModule {
        id: mod
        moduleId: root.blockId
        barWindow: host
        isSolid: root.flat
        isGrouped: root.grouped
        moduleActive: true
    }
}
