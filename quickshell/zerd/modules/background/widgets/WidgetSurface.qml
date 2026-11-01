import QtQuick
import qs.modules.common

// Lean stand-in for iNiR's WidgetSurface (a many-dialect panel with wallpaper glass).
// Draws a plain translucent rounded plate with a hairline; the properties the
// vendored widgets set are kept so their files parse.
Rectangle {
    id: root

    property bool shown: true
    property bool irisPresentation: true
    property real regionBrightness: -1
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080
    property real surfaceOpacity: 0.16
    property real surfaceBorderWidth: 1
    property real surfaceBorderOpacity: 0.2
    property color surfaceColor: "white"
    property color surfaceFill: "black"
    property string colorMode: "auto"
    property color surfaceAccent: "white"
    property real surfaceRadius: 22
    property bool surfaceUseBlur: false
    property bool powerActive: true

    visible: shown && surfaceOpacity > 0.001
    radius: surfaceRadius
    antialiasing: true
    color: Qt.rgba(surfaceFill.r, surfaceFill.g, surfaceFill.b, Math.min(1, surfaceOpacity * 2.2))
    border.width: surfaceBorderWidth
    border.color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, surfaceBorderOpacity)
}
