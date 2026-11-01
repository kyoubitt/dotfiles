import QtQuick
import qs.modules.common

// Natively rendered, unhinted text, same recipe as the lock screen.
Text {
    color: BarStyle.text
    renderType: Text.NativeRendering
    font.family: Appearance.font.family.expressive
    font.pixelSize: BarStyle.fontSize
    font.weight: Font.Medium
    font.hintingPreference: Font.PreferNoHinting
    lineHeightMode: Text.FixedHeight
    lineHeight: 2 * Math.ceil(font.pixelSize * 1.3 / 2)
    verticalAlignment: Text.AlignVCenter
    // Even whole-pixel size so centring inside a capsule never lands on a half pixel.
    width: 2 * Math.ceil(implicitWidth / 2)
    height: 2 * Math.ceil(implicitHeight / 2)
}
