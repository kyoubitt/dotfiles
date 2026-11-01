import QtQuick
import qs.modules.common
import qs.services

// Minimal stand-in for iNiR's AbstractBackgroundWidget (a 2.6k-line desktop-widget
// canvas with placement, resizing and an edit mode). The vendored widgets inherit
// from it, so this answers only what they read: their settings (defaults plus the
// overrides in `options`), a scale, and the shell's wallust palette. Editing,
// stacking and placement are not part of this shell.
Item {
    id: root

    property string configEntryName: ""
    property var defaultConfig: ({})
    property var options: ({})

    // Properties the widgets assign; kept so their files parse, and ignored.
    property var resizableAxes: ({})
    property real resizeMinWidth: 0
    property real resizeMinHeight: 0
    property bool visibleWhenLocked: false
    property bool needsColText: false
    property bool semanticPaletteQuickControls: false
    property Component editPopoverContent: null

    function _readConfigKey(key: string): var {
        return options[key] !== undefined ? options[key] : defaultConfig[key]
    }
    function _setOutputValue(key: string, value: var): void {}

    readonly property real scaleFactor: Math.max(0.2, Number(root._readConfigKey("widgetScale") ?? 100) / 100)
    property int cornerRadiusOverride: -1
    property int widgetCardRadius: 28
    readonly property real cardRadius: Math.round(widgetCardRadius * scaleFactor)
    readonly property real backgroundOpacity: Number(root._readConfigKey("backgroundOpacity") ?? 0.12)
    readonly property real borderWidth: Number(root._readConfigKey("borderWidth") ?? 1)
    readonly property real borderOpacity: Number(root._readConfigKey("borderOpacity") ?? 0.2)
    readonly property string colorMode: String(root._readConfigKey("colorMode") ?? "auto")
    readonly property bool effectiveBlur: false
    property real regionBrightness: -1
    property real scaledScreenWidth: 1920
    property real scaledScreenHeight: 1080
    property real regionBrightnessSpread: 0
    readonly property bool showBackground: Boolean(root._readConfigKey("showBackground") ?? true)
    property bool powerActive: true
    property bool motionActive: root.visible
    property bool widgetIris: true

    // Palette
    readonly property color widgetAccent: WallustTheme.accent
    readonly property color widgetAccentVisible: WallustTheme.accent
    readonly property color widgetAccent2: WallustColors.green
    readonly property color widgetAccent2Visible: WallustColors.green
    readonly property color widgetAccent3: WallustColors.cyan
    readonly property color widgetAccent3Visible: WallustColors.cyan
    readonly property color widgetPlateColor: WallustTheme.bgBase
    readonly property color widgetSurfaceInk: WallustTheme.textPrimary
    readonly property color widgetInk: WallustTheme.textPrimary
    readonly property color widgetInkMuted: WallustTheme.textSecondary

    property string widgetPrimaryRole: "primary"
    property string widgetSecondaryRole: "secondary"
    property string widgetTertiaryRole: "tertiary"
    property string widgetSignalRole: "error"
    property string widgetSurfaceRole: "surface"

    function _role(role: string): color {
        return role === "secondary" ? WallustColors.green
            : role === "tertiary" ? WallustColors.cyan
            : role === "error" ? WallustColors.red : WallustTheme.accent
    }
    function widgetSemanticColor(role: string): color { return _role(role) }
    function widgetSemanticForeground(role: string): color { return _role(role) }
    function widgetSemanticContainer(role: string): color { return Qt.rgba(_role(role).r * 0.35 + 0.05, _role(role).g * 0.35 + 0.05, _role(role).b * 0.35 + 0.05, 1) }
    function widgetSemanticOnContainer(role: string): color { return _role(role) }
}
