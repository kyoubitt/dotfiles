import QtQuick
import qs.modules.common
import qs.modules.waffle.startMenu

// Text for the lock screen, the shell's text recipe (see BarText): native rendering, Inter, full hinting up to
// 13 px so every stem lands on the pixel grid, default hinting above. Callers set the weight. The line height
// is a whole, even number of pixels so layouts never place text on a half pixel.
Text {
    // read through a plain property: a font binding that reads font.pixelSize itself loops
    readonly property int px: font.pixelSize
    color: SMColors.fg
    renderType: Text.NativeRendering
    font.family: Appearance.font.family.expressive
    font.hintingPreference: px <= 13 ? Font.PreferFullHinting : Font.PreferDefaultHinting
    font.kerning: true
    font.preferShaping: true
    lineHeightMode: Text.FixedHeight
    lineHeight: 2 * Math.ceil(font.pixelSize * 1.3 / 2)
}
