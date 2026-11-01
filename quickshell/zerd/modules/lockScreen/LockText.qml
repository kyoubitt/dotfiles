import QtQuick
import qs.modules.common
import qs.modules.waffle.startMenu

// Text for the lock screen. Native rendering without hinting keeps glyph
// shapes true and smooth on top of the blurred wallpaper (the default
// distance-field renderer looks grainy there). The line height is a whole
// number of pixels so layouts never place text on a half pixel.
Text {
    color: SMColors.fg
    renderType: Text.NativeRendering
    font.family: Appearance.font.family.expressive
    font.hintingPreference: Font.PreferNoHinting
    font.kerning: true
    font.preferShaping: true
    lineHeightMode: Text.FixedHeight
    lineHeight: Math.ceil(font.pixelSize * 1.3)
}
