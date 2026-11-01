import qs.modules.music
import QtQuick
import QtQuick.Shapes

// A Material 3 "cookie": a circle with soft lobes, drawn as a smooth polygon. Used for badges and the big play button.
Item {
    id: root
    property color color: "white"
    property int lobes: 9
    property real amp: 0.06
    property bool spin: false        // turns slowly while true (a playing song)
    property real spinMs: 9000
    implicitWidth: 56
    implicitHeight: 56
    readonly property var points: {
        const out = []; const n = 120
        const r0 = Math.min(root.width, root.height) / 2
        for (let i = 0; i <= n; i++) {
            const t = i / n * 2 * Math.PI
            const r = r0 * (1 - root.amp + root.amp * Math.cos(root.lobes * t))
            out.push(Qt.point(root.width / 2 + r * Math.cos(t), root.height / 2 + r * Math.sin(t)))
        }
        return out
    }
    Shape {
        anchors.fill: parent
        RotationAnimation on rotation { running: root.spin && root.visible; loops: Animation.Infinite; from: 0; to: 360; duration: root.spinMs }
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: root.color; strokeColor: "transparent"; PathPolyline { path: root.points } }
    }
}
