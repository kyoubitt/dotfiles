import QtQuick
import qs.modules.common

// Material Symbols glyph at a whole-pixel size.
// Measured: light hinting (default) snaps horizontal strokes to the pixel grid (peak coverage 1.0, no-hinting gave 0.6-0.9),
// and full hinting ignores the weight axis. The weight is picked per size so the stroke is about 2 px:
// 16 px 700, 18 px 650, 20 px 550, 24 px 400 (optical size follows the size, 20 to 48).
Item {
    id: root

    property string name: ""
    property real size: BarStyle.iconSize
    property real fill: 0
    property color color: BarStyle.text

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)

    Text {
        anchors.fill: parent
        text: root.name
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        font.family: Appearance.font.family.iconMaterial
        font.pixelSize: Math.round(root.size)
        font.hintingPreference: Font.PreferDefaultHinting
        font.variableAxes: ({
            "FILL": root.fill,
            "wght": root.size <= 16 ? 700 : root.size <= 18 ? 650 : root.size <= 20 ? 550 : root.size <= 24 ? 400 : 400,
            "opsz": root.size <= 20 ? 20 : Math.min(48, Math.round(root.size))
        })
    }
}
