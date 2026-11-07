import QtQuick

// The hover and press layer of a row or a button: BarStyle's state layers, the text colour at 8 % while hovered and
// 12 % while pressed. With `glide` it is the liquid hover of a capsule instead: one layer that slides to whichever
// `target` the pointer is on. The edge it moves towards runs ahead of the one it leaves, so it stretches on the way and
// settles; it swells a little while it travels and shrinks under a press, and where the pointer leaves it fades out
// (after the hover lens of ilyamiro's rice, serpantinum, AGPL-3.0).
Rectangle {
    id: root

    property bool hovered: false
    property bool pressed: false
    property bool glide: false
    property Item target: null
    property real inset: 0
    // a button in a capsule is lit a little more than a list row
    property real hoverAlpha: glide ? 0.12 : 0.08
    property real pressAlpha: glide ? 0.18 : 0.12
    // how long the leading and the trailing edge take
    property int fast: 170
    property int slow: 300

    readonly property bool has: glide && target !== null
    radius: glide ? Math.min(width, height) / 2 : BarStyle.radiusSmall
    antialiasing: true
    color: Qt.rgba(BarStyle.text.r, BarStyle.text.g, BarStyle.text.b, pressed ? pressAlpha : ((hovered || glide) ? hoverAlpha : 0))
    Behavior on color { ColorAnimation { duration: 120 } }

    // ---- glide: where the layer is going, where its four edges are, and whether it has been placed yet
    property real goalL: 0
    property real goalT: 0
    property real goalR: 0
    property real goalB: 0
    property real edgeL: goalL
    property real edgeT: goalT
    property real edgeR: goalR
    property real edgeB: goalB
    property bool placed: false
    property real lastX: 0
    property real lastY: 0

    Behavior on edgeL { enabled: root.placed; NumberAnimation { id: animL; duration: root.slow; easing.type: Easing.OutCubic } }
    Behavior on edgeR { enabled: root.placed; NumberAnimation { id: animR; duration: root.slow; easing.type: Easing.OutCubic } }
    Behavior on edgeT { enabled: root.placed; NumberAnimation { id: animT; duration: root.slow; easing.type: Easing.OutCubic } }
    Behavior on edgeB { enabled: root.placed; NumberAnimation { id: animB; duration: root.slow; easing.type: Easing.OutCubic } }

    Binding { target: root; property: "x"; value: root.edgeL; when: root.glide }
    Binding { target: root; property: "y"; value: root.edgeT; when: root.glide }
    Binding { target: root; property: "width"; value: Math.max(0, root.edgeR - root.edgeL); when: root.glide }
    Binding { target: root; property: "height"; value: Math.max(0, root.edgeB - root.edgeT); when: root.glide }

    function measure(): void {
        if (!root.glide || !root.target || !root.parent) return
        const p = root.target.mapToItem(root.parent, 0, 0)
        root.goalL = p.x + root.inset
        root.goalT = p.y + root.inset
        root.goalR = p.x + root.target.width - root.inset
        root.goalB = p.y + root.target.height - root.inset
    }

    onTargetChanged: {
        if (!root.glide || !root.target || !root.parent) return
        // which way it goes decides which edge leads
        const p = root.target.mapToItem(root.parent, 0, 0)
        const cx = p.x + root.target.width / 2
        const cy = p.y + root.target.height / 2
        if (root.placed) {
            if (cx > root.lastX) { animR.duration = root.fast; animL.duration = root.slow }
            else if (cx < root.lastX) { animL.duration = root.fast; animR.duration = root.slow }
            if (cy > root.lastY) { animB.duration = root.fast; animT.duration = root.slow }
            else if (cy < root.lastY) { animT.duration = root.fast; animB.duration = root.slow }
        }
        root.lastX = cx
        root.lastY = cy
        root.measure()
        if (!root.placed) Qt.callLater(() => { root.placed = true })
    }
    // the capsule moves and resizes under the pointer (labels change, items come and go): follow it while there is a target
    FrameAnimation { running: root.glide && root.target !== null; onTriggered: root.measure() }

    opacity: glide ? (has ? 1 : 0) : 1
    Behavior on opacity { enabled: root.glide; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    visible: !glide || has || opacity > 0
    onOpacityChanged: if (root.glide && opacity === 0 && !has) root.placed = false

    readonly property bool moving: glide && has && (Math.abs(edgeL - goalL) > 0.5 || Math.abs(edgeR - goalR) > 0.5
        || Math.abs(edgeT - goalT) > 0.5 || Math.abs(edgeB - goalB) > 0.5)
    property real lift: moving ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    scale: glide ? (pressed ? 0.92 : 1 + 0.07 * lift) : 1
    Behavior on scale { enabled: root.glide; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
}
