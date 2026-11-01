import QtQuick
import qs.modules.bars

// The interface text: Inter, and Inter Display (tighter, heavier) from 20 px up. The family and spacing follow the size
// through a guarded handler (setting only when it differs) because reading font.pixelSize inside a font binding loops.
BarText {
    function fit(): void {
        const px = font.pixelSize
        const fam = px >= 20 ? "Inter Display" : "Inter"
        const ls = px >= 24 ? -0.4 : (px >= 20 ? -0.2 : 0)
        if (font.family !== fam) font.family = fam
        if (font.letterSpacing !== ls) font.letterSpacing = ls
    }
    Component.onCompleted: fit()
    onFontChanged: fit()
}
