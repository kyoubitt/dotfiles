import QtQuick
import Quickshell.Widgets
import qs.modules.bars
import qs.modules.music

// An album, playlist or artist on a shelf: art, name, a line under it. Hover lifts it and brings a play button up
// with a spring; a click opens it.
Item {
    id: root
    required property var item
    property string kind: "playlist"          // playlist | album | artist
    property int artSize: 150
    width: artSize + 20
    height: artSize + 66
    signal opened()

    readonly property bool hot: hov.hovered
    Rectangle { anchors.fill: parent; radius: 22; color: root.hot ? BarStyle.plateHover : "transparent"; Behavior on color { ColorAnimation { duration: 90 } } }
    ClippingRectangle {
        id: art
        x: 10; y: 10; width: root.artSize; height: root.artSize
        radius: root.kind === "artist" ? root.artSize / 2 : 16
        color: BarStyle.plate
        scale: tap.pressed ? 0.96 : (root.hot ? 1.04 : 1)
        Behavior on scale { SpringAnimation { spring: 7; damping: 0.45 } }
        Image { anchors.fill: parent; scale: root.hot ? 1.07 : 1; Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } source: MusicStore.artOf(root.item, false); sourceSize: Qt.size(root.artSize * 2, root.artSize * 2); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: false }
    }
    // play
    Item {
        x: art.x + art.width - 52; y: art.y + art.height - 52 - (root.hot ? 0 : -10)
        width: 44; height: 44; opacity: root.hot ? 1 : 0
        Behavior on y { SpringAnimation { spring: 4; damping: 0.35 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Cookie { anchors.fill: parent; color: MusicStore.accent; lobes: 8; amp: 0.07; spin: true; spinMs: 10000 }
        BarIcon { anchors.centerIn: parent; name: MusicStore.playingContext(root.item.uri) ? "pause" : "play_arrow"; fill: 1; size: 24; color: MusicStore.onAccent }
        TapHandler { onTapped: MusicStore.toggleContext(root.item.uri) }
    }
    EText { x: 14; y: root.artSize + 18; width: parent.width - 28; elide: Text.ElideRight; text: root.item?.name ?? ""; font.weight: Font.DemiBold; horizontalAlignment: root.kind === "artist" ? Text.AlignHCenter : Text.AlignLeft }
    EText {
        x: 14; y: root.artSize + 38; width: parent.width - 28; elide: Text.ElideRight; font.pixelSize: 12; color: BarStyle.subtext
        horizontalAlignment: root.kind === "artist" ? Text.AlignHCenter : Text.AlignLeft
        text: root.kind === "album" ? ((root.item?.release_date ?? "").slice(0, 4) + (root.item?.artists ? "  ·  " + MusicStore.artistsOf(root.item) : "")) : (root.kind === "artist" ? "Artist" : (root.item?.owner?.display_name ?? "Playlist"))
    }
    HoverHandler { id: hov }
    TapHandler { id: tap; onTapped: { MusicStore.go(root.kind, root.item); root.opened() } }
}
