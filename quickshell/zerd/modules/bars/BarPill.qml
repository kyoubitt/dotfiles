import QtQuick
import qs

// A capsule that lays its children out in a row, or a column on a side bar.
// Hover lightens it; `clicked`/`wheel` come from the MouseArea underneath. Round buttons inside it (BarCell) share one
// liquid hover layer that glides from the one under the pointer to the next.
Rectangle {
    id: root

    property bool vertical: false
    property bool interactive: false
    // Scrolling over the capsule is reported through `wheel` even when it is not clickable as a whole.
    property bool wheelable: false
    // A HoverHandler, not the MouseArea's containsMouse: a hover-enabled MouseArea swallows the hover that the
    // bar's autohide (HoverHandlers on the groups) needs, and the bar would hide while the pointer is on a pill.
    property bool hovered: pillHover.hovered
    property int thickness: 30
    property string tip: ""
    // A strip of round buttons sits closer to the capsule's edge than a row of text does.
    property bool strip: false
    property int padding: strip ? 3 : BarStyle.padding
    property int spacing: strip ? 2 : BarStyle.gap
    // The button the pointer is on (set by BarCell); the shared hover layer follows it.
    property var hoverCell: null
    readonly property bool isBarPill: true
    default property alias content: layout.data
    signal clicked(var mouse)
    signal wheel(var event)
    // Opens a bar popup of this kind centred under the pill.
    function openPopup(kind: string): void {
        const p = root.mapToItem(null, root.width / 2, 0)
        BarState.sidebar = ""
        GlobalStates.barPopup = GlobalStates.barPopup?.kind === kind ? null : { kind: kind, x: p.x }
    }

    function even(v: real): int { return 2 * Math.ceil(v / 2) }
    implicitWidth: root.vertical ? root.thickness : even(layout.implicitWidth + 2 * root.padding)
    implicitHeight: root.vertical ? even(layout.implicitHeight + 2 * root.padding) : root.thickness
    radius: Math.min(width, height) / 2
    antialiasing: true
    color: root.interactive && (root.hovered || hover.pressed) ? BarStyle.plateHover : (BarStyle.flatPills && !root.vertical ? "transparent" : BarStyle.plate)
    scale: root.interactive && hover.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    border.width: BarStyle.flatPills && !root.vertical ? 0 : 1
    border.color: BarStyle.border
    Behavior on color { ColorAnimation { duration: 100 } }

    // under the buttons
    BarHoverFill {
        glide: true
        target: root.hoverCell
        pressed: root.hoverCell ? root.hoverCell.pressed === true : false
    }

    Grid {
        id: layout
        x: Math.round((root.width - implicitWidth) / 2)
        y: Math.round((root.height - implicitHeight) / 2)
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: root.vertical ? 1 : Math.max(1, visibleChildren.length)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.spacing
    }

    HoverHandler { id: pillHover; enabled: root.interactive }
    BarTip { text: root.tip }

    // Behind the children, so items inside a pill can take their own clicks.
    MouseArea {
        id: hover
        z: -1
        anchors.fill: parent
        enabled: root.interactive || root.wheelable
        acceptedButtons: root.interactive ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheel(wheel)
    }
}
