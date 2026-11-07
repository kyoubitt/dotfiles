pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

// One expressive shape per typed character. Each grows in with a springy overshoot and settles from the
// accent colour to the foreground colour. The row follows the newest character when the password outgrows
// the field.
//
// `state` (Item.state, set by LockSurface) says what the password check is doing to the shapes:
//   typing    - nothing
//   verifying - a pulse travels along the row while PAM checks
//   success   - the shapes burst outward in the accent colour
//   fail      - the shapes turn red and fall away
// Everything is computed from the state, the time since it changed (t) and the shape's index, so a shape
// that is created, reused or removed mid-animation never shows a stale pose.
Flickable {
    id: root

    required property int length
    property color warnColor: Appearance.colors.colError

    state: "typing"
    states: [
        State { name: "typing" },
        State { name: "verifying" },
        State { name: "success" },
        State { name: "fail" }
    ]

    interactive: false
    boundsBehavior: Flickable.StopAtBounds
    // clipped sideways only in effect: the field gives this item plenty of height so falling shapes stay visible
    clip: true
    contentWidth: dotsRow.implicitWidth
    contentX: Math.max(contentWidth - width, 0)
    Behavior on contentX {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    property real t: 0       // ms since the state changed
    property real phase: 0   // 0..1, loops while verifying
    onStateChanged: {
        root.t = 0
        tAnim.restart()
        if (root.state === "typing") root.replay()
    }
    signal replay()

    NumberAnimation { id: tAnim; target: root; property: "t"; from: 0; to: 1400; duration: 1400 }
    NumberAnimation on phase {
        running: root.state === "verifying"
        from: 0
        to: 1
        duration: 1100
        loops: Animation.Infinite
    }

    function clamp01(v) { return v < 0 ? 0 : (v > 1 ? 1 : v) }
    function rnd(i, k) { const x = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453; return x - Math.floor(x) }

    // -> [dx, dy (in shape sizes), scale, rotation, opacity, toAccent, toWarn]
    function effects(i) {
        const n = root.length
        if (root.state === "verifying") {
            const amp = clamp01(root.t / 160)
            let w = 0.5 + 0.5 * Math.sin((root.phase - i * 0.075) * 6.2831853)
            w = w * w * w * amp
            return [0, -0.12 * w, 1 + 0.36 * w, 0, 1, 0.92 * w, 0]
        }
        if (root.state === "success") {
            const u = clamp01((root.t - Math.min(i * 8, 40)) / 200)
            const e = 1 - (1 - u) * (1 - u) * (1 - u)
            const c = i - (n - 1) / 2
            return [c * 0.5 * e + (rnd(i, 1) - 0.5) * 0.9 * e, -(0.5 + rnd(i, 2) * 1.1) * e,
                    1 + 1.25 * e, (rnd(i, 3) - 0.5) * 90 * e, 1 - clamp01((u - 0.4) / 0.6), clamp01(root.t / 40), 0]
        }
        if (root.state === "fail") {
            const tint = clamp01(root.t / 100)
            const u = clamp01((root.t - 90 - Math.min(i * 20, 300)) / 520)
            return [(rnd(i, 4) - 0.5) * 0.9 * u, 4.4 * u * u, 1 - 0.3 * u, (rnd(i, 5) - 0.5) * 140 * u,
                    1 - clamp01((u - 0.2) / 0.8), 0, tint]
        }
        return [0, 0, 1, 0, 1, 0, 0]
    }

    Row {
        id: dotsRow
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 4
        }
        spacing: 10

        Repeater {
            model: root.length

            delegate: Item {
                id: charItem
                required property int index

                implicitWidth: 10
                implicitHeight: 10

                readonly property var fx: root.effects(charItem.index)
                property real settle: 0      // accent -> foreground

                Connections {
                    target: root
                    function onReplay() { appear.restart(); settleAnim.restart() }
                }

                Item {
                    id: wrap
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    opacity: charItem.fx[4]
                    transform: [
                        Scale { origin.x: 9; origin.y: 9; xScale: charItem.fx[2]; yScale: charItem.fx[2] },
                        Rotation { origin.x: 9; origin.y: 9; angle: charItem.fx[3] },
                        Translate { x: charItem.fx[0] * 18; y: charItem.fx[1] * 18 }
                    ]

                    MaterialShape {
                        id: shape
                        anchors.centerIn: parent

                        readonly property list<var> charShapes: [
                            MaterialShape.Shape.Clover4Leaf,
                            MaterialShape.Shape.Arrow,
                            MaterialShape.Shape.Pill,
                            MaterialShape.Shape.SoftBurst,
                            MaterialShape.Shape.Diamond,
                            MaterialShape.Shape.ClamShell,
                            MaterialShape.Shape.Pentagon,
                        ]
                        shape: charShapes[charItem.index % charShapes.length]

                        readonly property color base: Qt.tint(SMColors.accent, Qt.rgba(SMColors.fg.r, SMColors.fg.g, SMColors.fg.b, charItem.settle))
                        readonly property color withAccent: Qt.tint(base, Qt.rgba(SMColors.accent.r, SMColors.accent.g, SMColors.accent.b, charItem.fx[5]))
                        color: Qt.tint(withAccent, Qt.rgba(root.warnColor.r, root.warnColor.g, root.warnColor.b, charItem.fx[6]))
                        implicitSize: 0
                        opacity: 0
                        scale: 0.5

                        Component.onCompleted: { appear.start(); settleAnim.start() }

                        ParallelAnimation {
                            id: appear
                            NumberAnimation {
                                target: shape
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 50
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: shape
                                property: "scale"
                                from: 0.5
                                to: 1
                                duration: 200
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                            }
                            NumberAnimation {
                                target: shape
                                property: "implicitSize"
                                from: 0
                                to: 18
                                duration: 350
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                            }
                        }
                    }
                }

                NumberAnimation {
                    id: settleAnim
                    target: charItem
                    property: "settle"
                    from: 0
                    to: 1
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
