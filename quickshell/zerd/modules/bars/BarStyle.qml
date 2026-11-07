pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

// Sizes and colours shared by the bars. Colours come straight from the
// wallust palette, so a wallpaper change re-tints every bar.
Singleton {
    // The shell's one set of colours: iNiR's Material 3 layers and text (Appearance.colors, from the wallpaper), with the
    // accent from the wallpaper's palette or the one picked in Settings. Everything else reads these.
    readonly property var c: Appearance.colors
    readonly property color plate: c.colLayer1                    // bar capsules, panels
    // the bar plates: the surface with a little text and accent in it, a touch see-through
    readonly property color plateTint: Qt.alpha(Qt.tint(Qt.tint(WallustTheme.rawBackground, Qt.rgba(WallustTheme.textPrimary.r, WallustTheme.textPrimary.g, WallustTheme.textPrimary.b, 0.07)), Qt.rgba(accent.r, accent.g, accent.b, 0.08)), 0.88)
    readonly property color surface: c.colLayer1                  // popups, tooltips, anything over windows
    readonly property color card: c.colLayer2                     // a card on a panel
    readonly property color cardHigh: c.colLayer3                 // a card on a card, chips
    readonly property color text: c.colOnLayer1
    readonly property color subtext: c.colSubtext
    readonly property color border: c.colOutlineVariant
    readonly property color accent: WallustTheme.accent
    readonly property color onAccent: WallustTheme.textOnAccent
    // tonal accent: the accent faintly over the surface, for selected chips, tonal buttons, icon tiles
    readonly property color accentContainer: Qt.tint(c.colLayer2, Qt.rgba(accent.r, accent.g, accent.b, 0.26))
    readonly property color onAccentContainer: Qt.tint(c.colOnLayer1, Qt.rgba(accent.r, accent.g, accent.b, 0.35))
    // state layers: the text colour faintly over a surface (hover 8 %, press 12 %)
    readonly property color plateHover: Qt.tint(plate, Qt.rgba(text.r, text.g, text.b, 0.08))
    readonly property color plateActive: Qt.tint(plate, Qt.rgba(text.r, text.g, text.b, 0.12))
    readonly property color cardHover: Qt.tint(card, Qt.rgba(text.r, text.g, text.b, 0.08))

    // shared look tokens for the other bar widgets
    readonly property color plateGlass: Qt.rgba(1, 1, 1, 0.06)          // a chip or box on a dark scrim
    readonly property color hoverFill: Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color pressFill: Qt.rgba(text.r, text.g, text.b, 0.12)
    readonly property color focusRing: Qt.rgba(accent.r, accent.g, accent.b, 0.9)
    readonly property int focusRingWidth: 2

    readonly property int fontSize: 13
    readonly property int iconSize: 18
    // The strip and floating bar styles draw one plate behind everything, so the capsules themselves go flat.
    readonly property bool flatPills: (Config.options?.bars?.top?.look ?? "pills") !== "pills"
    readonly property int gap: 6
    readonly property int padding: 10

    // One look for every card, panel and chip: the same corners, the same hairline edge, the same shadow and motion.
    readonly property int radiusSmall: 12      // buttons, fields
    readonly property int radiusMedium: 17     // cards
    readonly property int radiusLarge: 23      // panels, banners
    readonly property int radiusXL: 30         // big surfaces
    readonly property color edge: Qt.rgba(border.r, border.g, border.b, 0.55)
    readonly property real shadowOpacity: 0.3
    readonly property int motionFast: 200      // iNiR elementMoveFast
    readonly property int motionNormal: 300    // iNiR elementResize
    readonly property int motionSlow: 500      // iNiR elementMove (expressive)
    readonly property var easeExpressive: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property var easeEmphasized: [0.05, 0.7, 0.1, 1.0, 1, 1]

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
    readonly property color danger: c.colError
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
