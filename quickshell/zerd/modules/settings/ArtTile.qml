import QtQuick
import qs.modules.bars
import qs.modules.common

// A choice drawn instead of named: a small screen showing what the option does. The bar height, the icon size and the
// notification width on it follow the real settings, so the picture is live.
Item {
    id: tile

    property string art: ""              // barlook | dockstyle | spectrum | scheme | banner | pill | edges
    property string val: ""
    property string label: ""
    property bool selected: false
    signal tapped()

    readonly property real barH: Config.getNestedValue("bars.top.height", 34)
    readonly property real iconPx: Config.getNestedValue("iris.dock.iconSize", 40)
    readonly property real noteW: Config.getNestedValue("bars.notifications.width", 380)
    readonly property bool lightScheme: art === "scheme" && val === "light"
    readonly property color screenColor: art === "scheme" ? (val === "light" ? Qt.rgba(0.96, 0.95, 0.97, 1) : val === "ink" ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(0.11, 0.11, 0.12, 1)) : BarStyle.cardHigh
    readonly property color inkColor: lightScheme ? Qt.rgba(0.2, 0.2, 0.25, 0.8) : Qt.rgba(1, 1, 1, 0.55)

    width: 104; height: 84

    Rectangle {
        id: face
        width: 104; height: 62
        radius: 12
        color: tile.screenColor
        border.width: tile.selected ? 2 : 1
        border.color: tile.selected ? BarStyle.accent : BarStyle.border
        clip: true
        Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }

        // scheme "auto": the right half is light
        Rectangle { visible: tile.art === "scheme" && tile.val === "auto"; x: 52; width: 52; height: parent.height; color: Qt.rgba(0.96, 0.95, 0.97, 1) }
        Rectangle { visible: tile.art === "scheme"; x: 14; y: 16; width: 40; height: 8; radius: 4; color: tile.val === "light" ? Qt.rgba(0.2, 0.2, 0.25, 0.7) : Qt.rgba(1, 1, 1, 0.5) }
        Rectangle { visible: tile.art === "scheme"; x: 14; y: 30; width: 28; height: 8; radius: 4; color: BarStyle.accent }

        // bar styles
        Rectangle { visible: tile.art === "barlook" && tile.val === "pills"; x: 7; y: 6; width: 22; height: Math.round(tile.barH * 0.26); radius: height / 2; color: tile.inkColor }
        Rectangle { visible: tile.art === "barlook" && tile.val === "pills"; x: 37; y: 6; width: 30; height: Math.round(tile.barH * 0.26); radius: height / 2; color: tile.inkColor }
        Rectangle { visible: tile.art === "barlook" && tile.val === "pills"; x: 75; y: 6; width: 22; height: Math.round(tile.barH * 0.26); radius: height / 2; color: tile.inkColor }
        Rectangle { visible: tile.art === "barlook" && tile.val === "strip"; width: 104; height: Math.round(tile.barH * 0.26) + 4; color: tile.inkColor }
        Rectangle { visible: tile.art === "barlook" && tile.val === "floating"; x: 8; y: 6; width: 88; height: Math.round(tile.barH * 0.26); radius: height / 2; color: tile.inkColor }

        // docks
        Rectangle { visible: tile.art === "dockstyle" && tile.val === "tiles"; x: 14; y: parent.height - h - 4; readonly property real h: Math.round(tile.iconPx * 0.3) + 6; width: 76; height: h; radius: 4; color: tile.inkColor
            Repeater { model: 4; Rectangle { required property int index; x: 6 + index * 17; anchors.verticalCenter: parent.verticalCenter; width: Math.round(tile.iconPx * 0.3); height: width; radius: 2; color: BarStyle.cardHigh } } }
        Rectangle { visible: tile.art === "dockstyle" && tile.val === "classic"; x: 20; y: parent.height - h - 4; readonly property real h: Math.round(tile.iconPx * 0.3) + 6; width: 64; height: h; radius: h / 2; color: tile.inkColor
            Repeater { model: 4; Rectangle { required property int index; x: 8 + index * 14; anchors.verticalCenter: parent.verticalCenter; width: Math.round(tile.iconPx * 0.3); height: width; radius: width / 2; color: BarStyle.cardHigh } } }

        // spectrum
        Rectangle { visible: tile.art === "spectrum" && tile.val === "wave"; x: -10; y: 40; width: 124; height: 40; radius: 20; color: BarStyle.accent; opacity: 0.55 }
        Rectangle { visible: tile.art === "spectrum" && tile.val === "inside"; x: 22; y: 38; width: 60; height: 16; radius: 5; color: tile.inkColor
            Repeater { model: 7; Rectangle { required property int index; x: 5 + index * 8; width: 4; height: 4 + (index % 3) * 3; y: 12 - height; radius: 2; color: BarStyle.accent } } }

        // banners and pills
        Rectangle { visible: tile.art === "banner"; width: Math.round(tile.noteW / 7.5); height: 14; radius: 5; color: tile.inkColor
            x: Math.round((parent.width - width) / 2); y: tile.val === "top" ? 6 : parent.height - height - 6 }
        Rectangle { visible: tile.art === "pill"; width: 34; height: 10; radius: 5; color: BarStyle.accent
            x: Math.round((parent.width - width) / 2); y: tile.val === "top" ? 6 : parent.height - height - 6 }

        // panel edges
        Rectangle { visible: tile.art === "edges" && (tile.val === "left" || tile.val === "both"); width: 8; height: parent.height; color: BarStyle.accent; opacity: 0.8 }
        Rectangle { visible: tile.art === "edges" && (tile.val === "right" || tile.val === "both"); x: parent.width - 8; width: 8; height: parent.height; color: BarStyle.accent; opacity: 0.8 }
    }
    BarText {
        y: 66
        width: tile.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        text: tile.label; font.pixelSize: 12; font.weight: tile.selected ? Font.DemiBold : Font.Medium
        color: tile.selected ? BarStyle.accent : BarStyle.subtext
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.tapped() }
}
