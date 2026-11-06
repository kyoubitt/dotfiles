import QtQuick
import qs.modules.common
import qs.modules.waffle.startMenu

// Material Symbols glyph for the lock screen. Always natively rendered and
// unhinted at a whole-pixel size: the shared MaterialSymbol switches to
// curve rendering for filled glyphs, which looks soft at small sizes.
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
        font.hintingPreference: Font.PreferNoHinting
        font.variableAxes: ({ "FILL": root.fill, "wght": root.iconSize <= 18 ? 600 : (root.iconSize <= 24 ? 500 : 400), "opsz": Math.max(20, Math.min(48, Math.round(root.iconSize))) })
    }
}
