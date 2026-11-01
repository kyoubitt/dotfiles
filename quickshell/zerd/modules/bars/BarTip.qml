import QtQuick
import Quickshell
import qs

// A small label under the parent item after the pointer rests on it. Not shown while a bar popup
// is open, and only one tip is ever visible: the last one to claim `BarState.tipOwner`.
Item {
    id: tip

    property string text: ""
    property int delay: 250
    // A MouseArea with hoverEnabled next to the tip swallows the hover before the handler sees it,
    // so such items pass its containsMouse in here.
    property bool external: false
    readonly property string uid: String(Math.random())
    readonly property bool wanted: (hover.hovered || external) && text.length > 0 && !GlobalStates.barPopup
    property bool ready: false
    property real ax: 0
    property real ay: 0
    readonly property bool active: ready && BarState.tipOwner === uid

    anchors.fill: parent
    onWantedChanged: {
        if (wanted) wait.restart()
        else {
            wait.stop()
            ready = false
            if (BarState.tipOwner === uid) BarState.tipOwner = ""
        }
    }

    HoverHandler { id: hover }
    // A label never outstays: some hover states stay "on" after the pointer has left the bar.
    Timer { id: life; interval: 2500; onTriggered: { tip.ready = false; if (BarState.tipOwner === tip.uid) BarState.tipOwner = "" } }
    Timer {
        id: wait
        interval: tip.delay
        onTriggered: {
            if (!tip.wanted) return
            // Where the label goes, in the bar window's coordinates: centred under this item.
            const p = tip.mapToItem(null, tip.width / 2, tip.height)
            tip.ax = p.x
            tip.ay = p.y + 6
            BarState.tipOwner = tip.uid
            tip.ready = true
            life.restart()
        }
    }

    PopupWindow {
        visible: tip.active
        color: "transparent"
        anchor.window: tip.QsWindow.window
        anchor.rect.x: tip.ax
        anchor.rect.y: tip.ay
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: plate.width
        implicitHeight: plate.height

        Rectangle {
            id: plate
            width: label.implicitWidth + 20
            height: 26
            radius: 13
            color: BarStyle.surface
            border.width: 1
            border.color: BarStyle.border
            BarText { id: label; anchors.centerIn: parent; text: tip.text; font.pixelSize: 12 }
        }
    }
}
