import QtQuick
import qs.modules.common

// Material Symbols glyph at a whole-pixel size.
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
        font.hintingPreference: Font.PreferNoHinting
        // sturdier strokes for small sizes: thin 400-weight lines are what read as grainy at 14 to 18 px
        font.variableAxes: ({ "FILL": root.fill, "wght": root.size <= 18 ? 600 : (root.size <= 24 ? 500 : 400), "opsz": Math.max(20, Math.min(48, Math.round(root.size))) })
    }
}
