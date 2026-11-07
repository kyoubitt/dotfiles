pragma Singleton
import QtQuick
import qs.modules.common as Common
import qs.services as Svc

QtObject {
    id: root

    readonly property var c: Common.Appearance.colors
    property string fontFamily: Common.Appearance.font.family.expressive
    property string iconFont: "JetBrainsMono Nerd Font Mono"
    property int borderRadius: 14
    property int clampedBorderRadius: borderRadius
    property real elementOpacity: 0.88
    property bool blurBackground: false
    property string blurStyle: "blur"
    readonly property bool glassActive: false
    readonly property bool liquidGlass: false

    // a soft tint of the accent over the surface, not flat black
    readonly property color base: Qt.tint(Qt.tint(c.colLayer1, Qt.rgba(text.r, text.g, text.b, 0.05)), Qt.rgba(blue.r, blue.g, blue.b, 0.10))
    readonly property color mantle: c.colLayer0
    readonly property color crust: Qt.darker(c.colLayer0, 1.25)
    readonly property color text: c.colOnLayer1
    readonly property color subtext0: c.colSubtext
    readonly property color subtext1: Qt.tint(c.colSubtext, Qt.rgba(text.r, text.g, text.b, 0.4))
    readonly property color onSurface: text
    readonly property color surface0: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.08))
    readonly property color surface1: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.13))
    readonly property color surface2: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.19))
    readonly property color overlay0: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.28))
    readonly property color overlay1: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.4))
    readonly property color overlay2: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.52))
    readonly property color blue: Svc.WallustTheme.accent
    readonly property color primary: blue
    readonly property color sapphire: Qt.lighter(blue, 1.2)
    readonly property color lavender: Qt.tint(blue, Qt.rgba(1, 1, 1, 0.3))
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color red: c.colError
    readonly property color maroon: "#eba0ac"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"

    function faded(col) {
        return Qt.alpha(col, root.elementOpacity);
    }
}
