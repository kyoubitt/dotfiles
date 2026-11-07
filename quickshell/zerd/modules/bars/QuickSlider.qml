// Material 3 slider after end-4/dots-hyprland's StyledSlider and QuickSliders (GPL-3.0).
import QtQuick

// A filled bar and a track split around a thin handle, with the icon at the far end that slips into the fill as it
// arrives. Dragging, clicking and the wheel all report through `moved`; while a drag is on, the pointer decides and
// the service value (which lags and rounds) is ignored until it has caught up.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property real step: 0.05
    signal moved(real v)

    readonly property int trackHeight: 30
    readonly property int trackRadius: 9
    readonly property int innerRadius: 2
    readonly property int margins: 4
    readonly property real handleWidth: area.pressed ? 2 : 4
    readonly property color fillColor: BarStyle.accent
    readonly property color trackColor: Qt.tint(BarStyle.cardHigh, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.2))

    implicitWidth: 260
    implicitHeight: 40

    readonly property bool dragging: area.pressed
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
    FrameAnimation { running: root.pending; onTriggered: { root.pending = false; root.moved(root.local) } }

    // where the handle's middle sits
    readonly property real eff: Math.max(1, root.width - 2 * root.margins)
    readonly property real centre: Math.round(root.margins + root.shown * root.eff)
    readonly property bool nearFull: root.shown >= 0.9

    // fill
    Rectangle {
        x: 0; y: Math.round((root.height - root.trackHeight) / 2)
        width: Math.max(0, root.centre - root.handleWidth / 2 - root.margins)
        height: root.trackHeight
        color: root.fillColor
        topLeftRadius: root.trackRadius; bottomLeftRadius: root.trackRadius
        topRightRadius: root.innerRadius; bottomRightRadius: root.innerRadius
    }
    // track
    Rectangle {
        x: root.centre + root.handleWidth / 2 + root.margins
        y: Math.round((root.height - root.trackHeight) / 2)
        width: Math.max(0, root.width - x)
        height: root.trackHeight
        color: root.trackColor
        topRightRadius: root.trackRadius; bottomRightRadius: root.trackRadius
        topLeftRadius: root.innerRadius; bottomLeftRadius: root.innerRadius
    }
    // handle
    Rectangle {
        x: root.centre - width / 2
        y: Math.round((root.height - height) / 2)
        width: root.handleWidth; height: root.trackHeight + 8
        radius: width / 2
        color: root.fillColor
        Behavior on width { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
    }
    // icon: on the track at the far end, in the fill once the fill gets there
    BarIcon {
        x: root.nearFull ? root.centre - 14 - width : root.width - 10 - width
        y: Math.round((root.height - height) / 2)
        name: root.icon; size: 20; fill: 1
        color: root.nearFull ? BarStyle.onAccent : BarStyle.text
        Behavior on x { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
    }

    function fromX(px: real): void {
        root.local = Math.max(0, Math.min(1, (px - root.margins) / root.eff))
        root.holding = true
        root.shown = root.local
        root.pending = true
    }
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: mouse => { release.stop(); root.fromX(mouse.x) }
        onReleased: release.restart()
        onPositionChanged: mouse => { if (pressed) root.fromX(mouse.x) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
