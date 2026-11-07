import QtQuick
import qs.modules.common

// The shell's text recipe (measured in a lab window, see the commit message):
//  - Native rendering, never the distance-field default: SDF is 9 % heavier and has more grey edge pixels at 10-12 px.
//  - Full hinting up to 13 px: Inter's bytecode hinting gives whole-pixel advances, so every stem lands the same way.
//    Light hinting plus fractional glyph positions is what looked grainy. From 14 px on both look the same, so default.
//  - At 13 px full hinting rounds the x-height up (+17 % ink), so Regular there keeps the weight Medium had before.
Text {
    // read through a plain property: a font binding that reads font.pixelSize itself loops
    readonly property int px: font.pixelSize
    color: BarStyle.text
    renderType: Text.NativeRendering
    font.family: Appearance.font.family.expressive
    font.pixelSize: BarStyle.fontSize
    font.weight: px === 13 ? Font.Normal : Font.Medium
    font.hintingPreference: px <= 13 ? Font.PreferFullHinting : Font.PreferDefaultHinting
    lineHeightMode: Text.FixedHeight
    lineHeight: 2 * Math.ceil(font.pixelSize * 1.3 / 2)
    verticalAlignment: Text.AlignVCenter
    // Whole, even pixel size so centring inside a capsule never lands on a half pixel. Only for one-line text:
    // elided or wrapped text takes the width its parent gives it.
    readonly property bool snapped: elide === Text.ElideNone && wrapMode === Text.NoWrap
    width: snapped ? 2 * Math.ceil(implicitWidth / 2) : implicitWidth
    height: 2 * Math.ceil(implicitHeight / 2)
}
