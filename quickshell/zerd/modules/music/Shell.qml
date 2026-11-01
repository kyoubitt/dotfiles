import QtQuick
import Quickshell.Widgets
import qs.modules.bars

// Orbit's frame: the sidebar, the top bar, the page, and the player bar. Pages slide and fade in when you move.
Item {
    id: root
    anchors.fill: parent
    signal openImmersive()
    onWidthChanged: MusicStore.narrow = root.width < 1150
    Component.onCompleted: MusicStore.narrow = root.width < 1150

    Backdrop { anchors.fill: parent }
    Sidebar { id: side; x: 0; y: 0; height: parent.height - bar.height + 2 }
    // while Spotify is limiting requests: saved copies are shown, and this says for how long
    Rectangle {
        id: limitBar
        z: 30; visible: MusicApi.limited
        readonly property real minsLeft: { MusicApi.limitTick; return Math.max(0, MusicApi.blockedUntil - Date.now()) / 60000 }
        x: stage.x + (stage.width - width) / 2; y: root.height - bar.height - 50
        width: lbRow.width + 32; height: 34; radius: 17
        color: Qt.rgba(0, 0, 0, 0.62); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        Row {
            id: lbRow; anchors.centerIn: parent; spacing: 10
            Item { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: MusicStore.accent }
                Item { anchors.fill: parent; RotationAnimation on rotation { running: limitBar.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 4000 }
                    Rectangle { x: 14; y: 7; width: 4; height: 4; radius: 2; color: "#ffffff" } } }
            EText { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: "#ffffff"
                text: "Spotify is limiting requests, showing saved copies · back in " + (limitBar.minsLeft >= 60 ? Math.floor(limitBar.minsLeft / 60) + " h " + Math.round(limitBar.minsLeft % 60) + " min" : Math.ceil(limitBar.minsLeft) + " min") }
        }
    }
    NavBar { id: top; x: side.width; y: 0; width: parent.width - side.width }

    ClippingRectangle {
        id: stage
        x: side.width + 2; y: top.height; width: parent.width - side.width - 10 - (MusicStore.nowShown ? now.width + 8 : (MusicStore.narrow ? lyricsSide.width + 8 : 0)); height: parent.height - top.height - bar.height + 2
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        radius: 26; color: Qt.rgba(0, 0, 0, 0.30)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
        Component { id: cHome; HomeView {} }
        Component { id: cSearch; SearchView {} }
        Component { id: cLiked; LikedView {} }
        Component { id: cLibrary; LibraryView {} }
        Component { id: cPlaylist; PlaylistView {} }
        Component { id: cAlbum; AlbumView {} }
        Component { id: cArtist; ArtistView {} }
        Component { id: cStats; StatsView {} }
        Component { id: cProfile; ProfileView {} }
        readonly property var map: ({ home: cHome, search: cSearch, liked: cLiked, library: cLibrary, playlist: cPlaylist, album: cAlbum, artist: cArtist, stats: cStats, profile: cProfile })

        Loader {
            id: page
            width: parent.width; height: parent.height
            // a new page slides up a little and fades in
            onLoaded: { opacity = 0; y = 10; slide.restart(); if (item) { item.width = Qt.binding(() => page.width); item.height = Qt.binding(() => page.height) } }
            ParallelAnimation {
                id: slide
                NumberAnimation { target: page; property: "opacity"; to: 1; duration: 110; easing.type: Easing.OutCubic }
                NumberAnimation { target: page; property: "y"; to: 0; duration: 150; easing.type: Easing.OutCubic }
            }
            // One load per move: the page type and what it shows (a playlist, an album) are both part of "where you are".
            function show(): void { sourceComponent = null; Qt.callLater(() => { sourceComponent = stage.map[MusicStore.page] ?? cHome }) }
            Component.onCompleted: show()
        }
        Connections { target: MusicStore; function onAtChanged() { page.show() } }
    }

    NowPanel { id: now; visible: MusicStore.nowShown; x: parent.width - width - 8; y: top.height; height: parent.height - top.height - bar.height + 2 }
    // narrow window: no big panel, but the words stay on the side
    LyricsSide { id: lyricsSide; visible: MusicStore.narrow; x: parent.width - width - 8; y: top.height; height: parent.height - top.height - bar.height + 2 }
    PlayerBar { id: bar; x: 0; y: parent.height - height; width: parent.width; onOpenImmersive: root.openImmersive() }
}
