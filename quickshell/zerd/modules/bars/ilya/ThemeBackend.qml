pragma Singleton
import QtQuick
import qs.modules.common as Common
import qs.services as Svc

QtObject {
    id: root

    readonly property var c: Common.Appearance.colors
    // the bar and its popups follow wallust (~/.cache/wallust/colors.json, watched by WallustTheme): background, foreground, colour4
    readonly property color bg: Svc.WallustTheme.rawBackground
    property string fontFamily: Common.Appearance.font.family.expressive
    property string iconFont: "JetBrainsMono Nerd Font Mono"
    property int borderRadius: 16
    property int clampedBorderRadius: borderRadius
    property real elementOpacity: liquidGlass ? 0.55 : 0.88
    property bool blurBackground: false
    property string blurStyle: "blur"
    readonly property bool glassActive: false
    // bars.liquidGlass: frosted, see-through cards and plates; off: solid
    readonly property bool liquidGlass: Common.Config.options?.bars?.liquidGlass ?? false

    // a soft tint of the accent over the surface, not flat black
    readonly property color base: Qt.tint(Qt.tint(bg, Qt.rgba(text.r, text.g, text.b, 0.07)), Qt.rgba(blue.r, blue.g, blue.b, 0.08))
    // popups and menus: the same tint, nearly opaque, so text over a busy window stays crisp
    readonly property color card: Qt.alpha(base, liquidGlass ? 0.55 : 0.97)
    readonly property color mantle: bg
    readonly property color crust: Qt.darker(bg, 1.4)
    readonly property color text: Svc.WallustTheme.textPrimary
    readonly property color subtext0: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.62))
    readonly property color subtext1: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.8))
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


    // Nerd Font glyph -> Material Symbol, so every bar icon is one font at one size
    readonly property var symbols: ({
        "F04C3": "speaker",
        "F04DB": "stop",
        "F02CB": "headphones",
        "F0214": "description",
        "F0450": "refresh",
        "F075A": "album",
        "F0156": "close",
        "F009A": "notifications",
        "F009B": "notifications_off",
        "F0079": "battery_full",
        "F0083": "battery_alert",
        "F0084": "battery_charging_full",
        "F0425": "power_settings_new",
        "F140B": "battery_alert",
        "F00AF": "bluetooth",
        "F00B2": "bluetooth_disabled",
        "F037D": "headphones",
        "F0388": "music_note",
        "F03E4": "pause",
        "F040A": "play_arrow",
        "F04AD": "skip_next",
        "F04AE": "skip_previous",
        "F057E": "volume_up",
        "F0580": "volume_down",
        "F0581": "volume_off",
        "F091F": "network_wifi_1_bar",
        "F0922": "network_wifi_2_bar",
        "F0925": "network_wifi_3_bar",
        "F0928": "wifi",
        "F092E": "wifi_off",
        "F092F": "wifi_off",
        "F0200": "lan",
        "F0493": "settings",
        "F0349": "search",
        "F0594": "bedtime",
        "F001D": "flight",
        "F0176": "coffee",
        "F049D": "shuffle",
        "F0599": "sunny",
        "F0595": "partly_cloudy_day",
        "F0590": "cloud",
        "F0591": "foggy",
        "F0593": "thunderstorm",
        "F0598": "weather_snowy",
        "F067F": "weather_mix",
        "F0597": "rainy"
    })
    function symOf(glyph) {
        const g = String(glyph || "");
        if (g.length === 0) return "";
        const cp = g.codePointAt(0);
        return cp >= 0xF0000 ? (root.symbols[cp.toString(16).toUpperCase()] ?? "") : "";
    }
    readonly property string symbolFont: "Material Symbols Rounded"

    // TEMP DEBUG: the resolved palette, printed whenever wallust changes it
    onBaseChanged: console.log("WALLDBG base", base, "text", text, "accent", blue)

    function faded(col) {
        return Qt.alpha(col, root.elementOpacity);
    }
}
