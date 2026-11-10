import QtQuick
import "ilya" as Ilya

// A rounded slider: the fill follows the value, the icon sits in the fill.
// Dragging, clicking and the wheel all report through `moved`.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property string label: ""
    property real step: 0.05
    property real minimum: 0
    property real maximum: 1
    property int trackHeight: 36
    property color tone: BarStyle.accent        // the fill; the volume popup passes its tab colour
    property bool muted: false
    signal moved(real v)

    implicitWidth: 260
    implicitHeight: trackHeight

    readonly property bool dragging: area.pressed
    // While dragging, the pointer decides; the service value lags and rounds, so it is ignored
    // until the drag has ended and the service has caught up (or 300 ms passed).
    property real local: 0
    property bool holding: false
    readonly property real target: Math.max(0, Math.min(1, root.holding ? root.local : value))
    property real shown: 0
    onTargetChanged: root.shown = root.target
    Component.onCompleted: root.shown = root.target
    Behavior on shown { enabled: !root.dragging && !root.holding; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Timer { id: release; interval: 300; onTriggered: root.holding = false }
    onValueChanged: if (!root.dragging && root.holding && Math.abs(value - root.local) < 0.02) { release.stop(); root.holding = false }
    // At most one update per frame goes to the service.
    property bool pending: false
    FrameAnimation { running: root.pending; onTriggered: { root.pending = false; root.moved(root.minimum + (root.maximum - root.minimum) * root.local) } }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: BarStyle.plateHover
        border.width: 1
        border.color: BarStyle.border
        clip: true

        Rectangle {
            width: Math.max(parent.height, parent.width * root.shown)
            height: parent.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.muted ? BarStyle.plateActive : Qt.darker(root.tone, 1.15) }
                GradientStop { position: 1; color: root.muted ? BarStyle.plateActive : Qt.lighter(root.tone, 1.12) }
            }
            // the handle: a short bar at the end of the fill that thickens under the pointer
            Rectangle {
                visible: root.shown > 0.04 && root.shown < 0.985
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - width - 6
                width: root.dragging ? 6 : (hov.hovered ? 5 : 4); height: Math.max(12, parent.height - 14); radius: width / 2
                color: BarStyle.onAccent; opacity: 0.85
                Behavior on width { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutBack } }
            }
        }
    }
    HoverHandler { id: hov }
    BarIcon {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        name: root.icon; fill: 1
        color: BarStyle.onAccent
    }
    BarText {
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.label.length > 0 ? root.label : Math.round(root.shown * 100) + "%"
        font.weight: Font.DemiBold
        color: root.shown > 0.88 ? BarStyle.onAccent : BarStyle.text
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    property real lastTick: -1
    function fromX(x: real): void {
        root.local = Math.max(0, Math.min(1, x / width))
        if (Math.abs(root.local - root.lastTick) >= 0.04) { root.lastTick = root.local; Ilya.Sounds.playSfx("reusables/draggable/tick.wav", 0.4) }
        root.holding = true
        root.shown = root.local
        root.pending = true
    }
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { release.stop(); root.fromX(mouse.x) }
        onReleased: release.restart()
        onPositionChanged: mouse => { if (pressed) root.fromX(mouse.x) }
        onWheel: wheel => root.moved(Math.max(root.minimum, Math.min(root.maximum, root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
