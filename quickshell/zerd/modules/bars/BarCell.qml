import QtQuick
import qs

// One round button inside a capsule (BarPill). It tells the capsule when the pointer is on it, so the capsule's shared
// hover layer glides here, and gives the click, the right and middle click and the wheel as signals. Whatever it holds
// (an icon, a label, an app icon) sits in the middle; `fill` paints a round behind it for a button that is switched on.
Item {
    id: cell

    property string tip: ""
    property bool interactive: true
    // Wheel events are only taken when something listens; otherwise they fall through to the capsule.
    property bool wheelEnabled: false
    property int padding: 6
    property color fill: "transparent"
    readonly property bool hovered: hv.hovered
    readonly property bool pressed: ma.pressed
    default property alias content: slot.data
    signal tapped()
    signal secondary()
    signal middle()
    signal wheel(var event)

    // The capsule this button lives in (found by walking up), so it can hand over its hover.
    readonly property var plate: {
        let p = cell.parent
        while (p) {
            if (p.isBarPill === true) return p
            p = p.parent
        }
        return null
    }
    onHoveredChanged: {
        if (!plate) return
        if (hovered) plate.hoverCell = cell
        else if (plate.hoverCell === cell) plate.hoverCell = null
    }
    Component.onDestruction: { if (plate && plate.hoverCell === cell) plate.hoverCell = null }

    implicitWidth: Math.max(28, Math.ceil(slot.implicitWidth) + 2 * padding)
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: cell.fill
        Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
    }
    Row {
        id: slot
        x: Math.round((cell.width - width) / 2)
        y: Math.round((cell.height - height) / 2)
        spacing: 4
        scale: cell.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: hv; enabled: cell.interactive; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: cell.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) cell.secondary()
            else if (mouse.button === Qt.MiddleButton) cell.middle()
            else cell.tapped()
        }
        onWheel: wheel => { wheel.accepted = cell.wheelEnabled; if (cell.wheelEnabled) cell.wheel(wheel) }
    }
    BarTip { text: cell.tip }
}
