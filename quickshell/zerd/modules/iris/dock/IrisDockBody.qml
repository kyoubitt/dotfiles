import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// The Dock's plate when it sits on the screen edge: flat on the bottom, rounded on the top, and flared at the two
// bottom corners with concave curves (the "cut-out" corners), so it grows out of the edge instead of floating.
// `width` includes the flared feet; `height` is the plate's height.
Item {
    id: root
    property real fillet: 20          // radius of the flared feet
    property real corner: 16          // radius of the top corners
    property color color: IrisStyle.surfaceOpaque
    readonly property real r: Math.min(root.fillet, root.height / 2, root.width / 4)
    readonly property real t: Math.min(root.corner, root.height / 2, (root.width - root.r * 2) / 2)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            PathSvg {
                path: {
                    const w = root.width, h = root.height, r = root.r, t = root.t
                    return "M 0," + h
                        + " A " + r + "," + r + " 0 0 0 " + r + "," + (h - r)
                        + " L " + r + "," + t
                        + " A " + t + "," + t + " 0 0 1 " + (r + t) + ",0"
                        + " L " + (w - r - t) + ",0"
                        + " A " + t + "," + t + " 0 0 1 " + (w - r) + "," + t
                        + " L " + (w - r) + "," + (h - r)
                        + " A " + r + "," + r + " 0 0 0 " + w + "," + h
                        + " Z"
                }
            }
        }
    }
    // a thin light edge along the top, like a lip
    Rectangle {
        x: root.r + root.t; y: 0; width: Math.max(0, root.width - 2 * (root.r + root.t)); height: 1
        color: Qt.rgba(1, 1, 1, 0.10)
    }
}
