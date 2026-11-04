import QtQuick
import Quickshell.Widgets
import qs.modules.common.widgets

// The picture on a notification: the app's icon on a soft tile tinted from the wallpaper accent. A picture that
// came with the notification (an avatar, cover art) takes the tile and the app icon becomes a badge on its corner.
Item {
    id: root

    property string appIcon: ""
    property string image: ""
    property int size: 42
    readonly property bool hasImage: image.length > 0

    width: size; height: size

    ClippingRectangle {
        anchors.fill: parent
        radius: Math.round(root.size * 0.3)
        color: root.hasImage ? BarStyle.plateHover : Qt.tint(BarStyle.plateHover, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.2))
        border.width: 1
        border.color: BarStyle.edge
        IconImage { visible: root.hasImage; anchors.fill: parent; source: root.hasImage ? root.image : ""; mipmap: true }
        SmartAppIcon { visible: !root.hasImage; anchors.centerIn: parent; icon: root.appIcon; iconSize: Math.round(root.size * 0.66) }
    }
    // with a picture, the app icon is a small badge on its corner
    Rectangle {
        visible: root.hasImage
        x: root.size - width + 4; y: root.size - height + 4
        width: Math.round(root.size * 0.5); height: width; radius: width / 2
        color: BarStyle.surface
        SmartAppIcon { anchors.centerIn: parent; icon: root.appIcon; iconSize: Math.round(parent.width * 0.72) }
    }
}
