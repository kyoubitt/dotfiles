import QtQuick
import qs.modules.common

// Self-contained vector folder icon - deliberately does NOT depend on
// system icon-theme resolution (Quickshell.iconPath/QIcon::fromTheme).
// That lookup silently falls back to a generic broken-icon glyph whenever
// the configured theme name doesn't match what's actually installed (as
// happened with the icon AND cursor themes elsewhere in this config), so
// directory entries in the wallpaper picker draw their own shape instead.
Item {
    id: root
    required property var fileModelData

    readonly property color folderColor: Appearance.colors.colSecondary ?? Appearance.colors.colPrimary

    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.55
        height: width * 0.72

        Rectangle {
            id: tab
            width: parent.width * 0.45
            height: parent.height * 0.22
            radius: 3
            color: root.folderColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Rectangle {
            width: parent.width
            height: parent.height * 0.85
            radius: 5
            color: root.folderColor
            anchors.bottom: parent.bottom
            anchors.left: parent.left
        }
    }
}
