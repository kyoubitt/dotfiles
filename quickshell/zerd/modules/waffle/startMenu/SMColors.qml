pragma Singleton
import QtQuick
import qs.services

// The menu, lock screen and panels share one colour source with the bar and the dock: the live wallust palette
// (services/WallustTheme), so everything changes together the moment the wallpaper does. An accent picked in
// Settings wins there too.
QtObject {
    readonly property color bg: Qt.rgba(WallustTheme.bgBase.r, WallustTheme.bgBase.g, WallustTheme.bgBase.b, 1)
    readonly property color fg: WallustTheme.textPrimary
    readonly property color accent: WallustTheme.accent
}
