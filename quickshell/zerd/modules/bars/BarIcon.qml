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
        renderType: Text.QtRendering
        font.family: Appearance.font.family.iconMaterial
        font.pixelSize: Math.round(root.size)
        font.hintingPreference: Font.PreferNoHinting
        font.variableAxes: ({ "FILL": root.fill, "opsz": Math.round(root.size) })
    }
}
