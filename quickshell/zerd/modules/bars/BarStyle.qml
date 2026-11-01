pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

// Sizes and colours shared by the bars. Colours come straight from the
// wallust palette, so a wallpaper change re-tints every bar.
Singleton {
    readonly property color plate: WallustTheme.bgBase
    // Same colour, fully opaque: for popups, panels and tooltips that sit over arbitrary windows.
    readonly property color surface: Qt.rgba(WallustTheme.bgBase.r, WallustTheme.bgBase.g, WallustTheme.bgBase.b, 1)
    readonly property color plateHover: Qt.lighter(WallustTheme.bgCard, 1.25)
    readonly property color border: WallustTheme.cardBorder
    readonly property color text: WallustTheme.textPrimary
    readonly property color subtext: WallustTheme.textSecondary
    readonly property color accent: WallustTheme.accent
    readonly property color onAccent: WallustTheme.textOnAccent

    readonly property int fontSize: 13
    readonly property int iconSize: 18
    readonly property int gap: 6
    readonly property int padding: 10

    // wttr.in weather codes -> Material symbol and plain text.
    function weatherIcon(code: var): string {
        const c = parseInt(code)
        if (c === 113) return "sunny"
        if (c === 116) return "partly_cloudy_day"
        if (c === 119 || c === 122) return "cloud"
        if ([143, 248, 260].includes(c)) return "foggy"
        if ([200, 386, 389, 392, 395].includes(c)) return "thunderstorm"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return "weather_snowy"
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(c)) return "weather_mix"
        if ([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(c)) return "rainy"
        return "partly_cloudy_day"
    }
    // The weather icon takes the colour of the sky, softened so it still sits in the palette.
    function weatherColor(code: var): color {
        const c = parseInt(code)
        if (c === 113) return "#f2c46d"
        if (c === 116) return "#e9cf8f"
        if ([200, 386, 389, 392, 395].includes(c)) return "#f0b45a"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return "#cfe4f7"
        if ([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359, 182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(c)) return "#7fb6e6"
        return BarStyle.subtext
    }
    // Warnings and "critical" stay red whatever the wallpaper is: one place to change it.
    readonly property color danger: Qt.hsla(0.012, 0.72, 0.68, 1)
    readonly property color warm: "#e8a77c"
    readonly property color cool: "#7fb6e6"
    function weatherText(code: var): string {
        const c = parseInt(code)
        if (c === 113) return "Clear"
        if (c === 116) return "Partly cloudy"
        if (c === 119) return "Cloudy"
        if (c === 122) return "Overcast"
        if ([143, 248, 260].includes(c)) return "Fog"
        if ([200, 386, 389, 392, 395].includes(c)) return "Thunderstorm"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return "Snow"
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(c)) return "Sleet"
        if ([263, 266, 293, 296, 299, 302, 305, 308, 353, 356, 359].includes(c)) return "Rain"
        return "Mixed"
    }
}
