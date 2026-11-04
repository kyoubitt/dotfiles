import QtQuick
import qs

// A capsule that lays its children out in a row, or a column on a side bar.
// Hover lightens it; `clicked`/`wheel` come from the MouseArea underneath.
Rectangle {
    id: root

    property bool vertical: false
    property bool interactive: false
    // A HoverHandler, not the MouseArea's containsMouse: a hover-enabled MouseArea swallows the hover that the
    // bar's autohide (HoverHandlers on the groups) needs, and the bar would hide while the pointer is on a pill.
    property bool hovered: pillHover.hovered
    property int thickness: 30
    property string tip: ""
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
    implicitWidth: root.vertical ? root.thickness : even(layout.implicitWidth + 2 * BarStyle.padding)
    implicitHeight: root.vertical ? even(layout.implicitHeight + 2 * BarStyle.padding) : root.thickness
    radius: Math.min(width, height) / 2
    antialiasing: true
    color: root.interactive && (root.hovered || hover.pressed) ? BarStyle.plateHover : BarStyle.plate
    scale: root.interactive && hover.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    border.width: 1
    border.color: BarStyle.border
    Behavior on color { ColorAnimation { duration: 100 } }

    Grid {
        id: layout
        x: Math.round((root.width - implicitWidth) / 2)
        y: Math.round((root.height - implicitHeight) / 2)
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: root.vertical ? 1 : Math.max(1, visibleChildren.length)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: BarStyle.gap
    }

    HoverHandler { id: pillHover; enabled: root.interactive }
    BarTip { text: root.tip }

    // Behind the children, so items inside a pill can take their own clicks.
    MouseArea {
        id: hover
        z: -1
        anchors.fill: parent
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheel(wheel)
    }
}
