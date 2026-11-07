import QtQuick
import qs.modules.common
import qs.modules.waffle.startMenu

// Material Symbols glyph for the lock screen at a whole-pixel size, same recipe as BarIcon: default (light)
// hinting snaps the horizontal strokes to the grid; the weight is picked per size so the stroke is about 2 px.
// Not the shared MaterialSymbol: it switches to curve rendering for filled glyphs, which looks soft here.
Item {
    id: root

    property string text: ""
    property real iconSize: 20
    property real fill: 0
    property color color: SMColors.fg

    implicitWidth: Math.round(iconSize)
    implicitHeight: Math.round(iconSize)

    Text {
        anchors.fill: parent
        text: root.text
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        font.family: Appearance.font.family.iconMaterial
        font.pixelSize: Math.round(root.iconSize)
        font.hintingPreference: Font.PreferDefaultHinting
        font.variableAxes: ({
            "FILL": root.fill,
            "wght": root.iconSize <= 16 ? 700 : root.iconSize <= 18 ? 650 : root.iconSize <= 20 ? 550 : 400,
            "opsz": root.iconSize <= 20 ? 20 : Math.min(48, Math.round(root.iconSize))
        })
    }
}
