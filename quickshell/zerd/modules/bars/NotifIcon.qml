import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets

// The picture on a notification, chosen the way iNiR does it: a picture that came with the notification wins (the
// app icon becomes a badge); else the app's own icon; else a symbol guessed from the title ("battery" -> power,
// "screenshot" -> screenshot, ...). It sits on a soft tile tinted from the wallpaper accent.
Item {
    id: root

    property string appName: ""
    property string appIcon: ""        // what the app sent, may be empty
    property string summary: ""
    property string image: ""
    property bool critical: false
    property int size: 42

    readonly property bool hasImage: image.length > 0
    // the app's own icon: what it sent, else its desktop entry's
    readonly property string iconName: appIcon.length > 0 ? appIcon : (AppSearch.lookupDesktopEntry(appName)?.icon ?? "")
    readonly property string symbol: NotificationUtils.findSuitableMaterialSymbol(summary)
    // a title that clearly says what it is ("screenshot", "battery") beats a generic app icon
    readonly property bool useSymbol: !hasImage && (iconName.length === 0 || (symbol !== "chat" && appIcon.length === 0))

    width: size; height: size

    // iNiR's shape: a round tile (a soft burst when urgent) in the accent container colour, the app's own icon or
    // a symbol guessed from the title on it; a picture that came with the notification fills a circle instead.
    MaterialShape {
        visible: !root.hasImage
        anchors.fill: parent
        implicitSize: root.size
        shape: root.critical ? MaterialShape.Shape.SoftBurst : MaterialShape.Shape.Circle
        color: root.critical
            ? Qt.tint(BarStyle.plateHover, Qt.rgba(BarStyle.danger.r, BarStyle.danger.g, BarStyle.danger.b, 0.45))
            : BarStyle.accentContainer
    }
    ClippingRectangle {
        visible: root.hasImage
        anchors.fill: parent
        radius: width / 2
        color: BarStyle.plateHover
        IconImage { anchors.fill: parent; source: root.hasImage ? root.image : ""; mipmap: true }
    }
    SmartAppIcon { visible: !root.hasImage && !root.useSymbol; anchors.centerIn: parent; icon: root.iconName; iconSize: Math.round(root.size * 0.62) }
    BarIcon {
        visible: root.useSymbol
        anchors.centerIn: parent
        name: root.critical && root.symbol === "chat" ? "priority_high" : root.symbol
        size: Math.round(root.size * 0.54); fill: 1
        color: root.critical ? BarStyle.danger : BarStyle.onAccentContainer
    }
    // with a picture, the app icon is a small badge on its corner
    Rectangle {
        visible: root.hasImage && root.iconName.length > 0
        x: root.size - width + 4; y: root.size - height + 4
        width: Math.round(root.size * 0.5); height: width; radius: width / 2
        color: BarStyle.surface
        SmartAppIcon { anchors.centerIn: parent; icon: root.iconName; iconSize: Math.round(parent.width * 0.72) }
    }
}
