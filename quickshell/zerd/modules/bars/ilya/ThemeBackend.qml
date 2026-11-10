pragma Singleton
import QtQuick
import qs.modules.common as Common
import qs.modules.bars
import qs.services as Svc

QtObject {
    id: root

    readonly property var c: Common.Appearance.colors
    // the bar and its popups follow wallust (~/.cache/wallust/colors.json, watched by WallustTheme): background, foreground, colour4
    readonly property color bg: Svc.WallustTheme.rawBackground
    property string fontFamily: Common.Appearance.font.family.expressive
    property string iconFont: "JetBrainsMono Nerd Font Mono"
    // one scale for the whole shell: BarStyle's corners and motion
    property int borderRadius: BarStyle.radiusMedium
    readonly property int cardRadius: BarStyle.radiusLarge       // popups and panels
    readonly property color cardEdge: BarStyle.edge              // their hairline border
    readonly property int motionFast: BarStyle.motionFast
    readonly property int motionNormal: BarStyle.motionNormal
    property int clampedBorderRadius: borderRadius
    property real elementOpacity: liquidGlass ? 0.55 : 0.88
    property bool blurBackground: false
    property string blurStyle: "blur"
    readonly property bool glassActive: false
    // bars.liquidGlass: frosted, see-through cards and plates; off: solid
    readonly property bool liquidGlass: Common.Config.options?.bars?.liquidGlass ?? false

    // surfaces and text are BarStyle's (iNiR's layers over the wallpaper), so a popup, Orbit, Settings and the side panels
    // are the same material
    readonly property color base: BarStyle.surface
    readonly property color card: Qt.alpha(base, liquidGlass ? 0.55 : 0.97)
    readonly property color mantle: bg
    readonly property color crust: Qt.darker(bg, 1.4)
    readonly property color text: BarStyle.text
    readonly property color subtext0: BarStyle.subtext
    readonly property color subtext1: Qt.tint(BarStyle.subtext, Qt.rgba(text.r, text.g, text.b, 0.3))
    readonly property color onSurface: text
    readonly property color surface0: BarStyle.card
    readonly property color surface1: BarStyle.cardHigh
    readonly property color surface2: Qt.tint(BarStyle.cardHigh, Qt.rgba(text.r, text.g, text.b, 0.07))
    readonly property color overlay0: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.28))
    readonly property color overlay1: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.4))
    readonly property color overlay2: Qt.tint(base, Qt.rgba(text.r, text.g, text.b, 0.52))
    readonly property color blue: BarStyle.accent
    readonly property color primary: blue
    readonly property color sapphire: Qt.lighter(blue, 1.2)
    readonly property color lavender: Qt.tint(blue, Qt.rgba(1, 1, 1, 0.3))
    readonly property color mauve: BarStyle.accent
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
        "F004D": "arrow_back",
        "F007": "person",
        "F00DE": "brightness_medium",
        "F00DF": "brightness_medium",
        "F00E0": "brightness_high",
        "F00EC": "calculate",
        "F00ED": "calendar_month",
        "F0100": "photo_camera",
        "F011": "power_settings_new",
        "F0142": "chevron_right",
        "F0169": "data_object",
        "F018D": "terminal",
        "F01B4": "delete",
        "F01DA": "download",
        "F0202": "link_off",
        "F0208": "visibility",
        "F0219": "description",
        "F0226": "picture_as_pdf",
        "F023": "lock",
        "F024B": "folder",
        "F02CE": "headset_mic",
        "F02DC": "home",
        "F02E9": "image",
        "F02FD": "info",
        "F0343": "logout",
        "F036C": "mic",
        "F0386": "library_music",
        "F043": "water_drop",
        "F046E": "directions_run",
        "F048B": "dns",
        "F04C5": "speed",
        "F053": "chevron_left",
        "F054": "chevron_right",
        "F0567": "videocam",
        "F059F": "language",
        "F05A7": "wb_iridescent",
        "F05AA": "wifi_off",
        "F06B0": "update",
        "F06EB": "folder_zip",
        "F0949": "bluetooth_connected",
        "F099D": "lock",
        "F0A5F": "router",
        "F0C2": "cloud",
        "F0D46": "apps",
        "F104": "chevron_left",
        "F105": "chevron_right",
        "F2C8": "thermostat",
        "E27E": "air",
        "E371": "water_drop",
        "F0A79": "delete",
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
        return cp >= 0xE000 ? (root.symbols[cp.toString(16).toUpperCase()] ?? "") : "";
    }
    readonly property string symbolFont: "Material Symbols Rounded"


    function faded(col) {
        return Qt.alpha(col, root.elementOpacity);
    }
}
