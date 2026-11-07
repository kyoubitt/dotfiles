import QtQuick
import QtQuick.Shapes

// A ring that fills clockwise from the top: the level of volume or brightness around an icon.
Item {
    id: root

    property real value: 0
    property real size: 26
    property real lineWidth: 2
    property color color: BarStyle.accent
    property color track: Qt.rgba(BarStyle.text.r, BarStyle.text.g, BarStyle.text.b, 0.16)

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: root.lineWidth
        border.color: root.track
        antialiasing: true
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.value > 0.004
        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.lineWidth) / 2
                radiusY: (root.size - root.lineWidth) / 2
                startAngle: -90
                sweepAngle: 359.9 * Math.max(0, Math.min(1, root.value))
            }
        }
    }
}
