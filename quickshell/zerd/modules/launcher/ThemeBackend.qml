pragma Singleton
import QtQuick
import qs.modules.common
import qs.modules.bars

// The launcher's colour names, on the shell's Material 3 base (BarStyle / wallust accent).
QtObject {
    readonly property color base: BarStyle.surface
    readonly property color crust: Qt.darker(BarStyle.surface, 1.25)
    readonly property color surface0: BarStyle.card
    readonly property color surface1: BarStyle.cardHigh
    readonly property color surface2: Qt.lighter(BarStyle.cardHigh, 1.25)
    readonly property color text: BarStyle.text
    readonly property color subtext0: BarStyle.subtext
    readonly property color mauve: BarStyle.accent
    readonly property color blue: BarStyle.accent
    readonly property color red: BarStyle.danger
    readonly property real borderRadius: BarStyle.radiusMedium
    readonly property real elementOpacity: 1.0
    readonly property bool liquidGlass: false
    readonly property bool glassActive: false
    readonly property string fontFamily: Appearance.font.family.expressive
}
