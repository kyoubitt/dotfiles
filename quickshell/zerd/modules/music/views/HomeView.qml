import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.modules.bars
import qs.modules.music

// Home: a greeting, the song you are on (or your last), your shortcuts, then shelves.
Flickable {
    id: root
    contentHeight: col.implicitHeight + 60
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    readonly property string greeting: { const h = new Date().getHours(); return h < 5 ? "Still up" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening" }
    readonly property var p: Playback.player

    Column {
        id: col
        x: 34; y: 26; width: root.width - 68; spacing: 14
        EText { text: root.greeting + (MusicStore.name.length > 0 ? ", " + MusicStore.name.split(" ")[0] : ""); font.pixelSize: 32; font.weight: Font.Bold }

        // spotlight: what is playing now, over its own blurred cover
        ClippingRectangle {
            width: parent.width; height: 200; radius: 34; color: BarStyle.plate
            Image { anchors.fill: parent; source: CoverCache.src(root.p?.trackArtUrl ?? ""); sourceSize: Qt.size(160, 160); fillMode: Image.PreserveAspectCrop; smooth: true; cache: true
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48; saturation: 0.25; brightness: -0.18 } }
            Rectangle { anchors.fill: parent; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#d9000000" } GradientStop { position: 1; color: "#80000000" } } }
            ClippingRectangle {
                x: 24; anchors.verticalCenter: parent.verticalCenter; width: 152; height: 152; radius: 23; color: BarStyle.plate
                Image { anchors.fill: parent; source: CoverCache.src(root.p?.trackArtUrl ?? ""); sourceSize: Qt.size(300, 300); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: true }
            }
            Column {
                x: 204; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 380; spacing: 5
                EText { text: Playback.isPlaying ? "Now playing" : "Paused"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#ffffff"; opacity: 0.75 }
                EText { visible: (MusicStore.ctx?.name ?? "").length > 0; text: "Playing from " + (MusicStore.ctx?.name ?? ""); font.pixelSize: 12; font.weight: Font.DemiBold; color: MusicStore.accent
                    TapHandler { onTapped: MusicStore.openContext() } }
                BarMarquee { width: parent.width; height: 36; text: root.p?.trackTitle ?? "Nothing playing"; pixelSize: 26; weight: Font.Bold; color: "#ffffff" }
                BarMarquee { width: parent.width; height: 22; text: root.p?.trackArtist ?? ""; pixelSize: 14; weight: Font.Normal; color: "#ccffffff" }
                WavySeek {
                    width: parent.width; playing: Playback.isPlaying; tint: "#ffffff"
                    progress: (root.p && root.p.length > 0) ? Math.min(1, root.p.position / root.p.length) : 0
                    onSeek: f => { if (root.p && root.p.length > 0) root.p.position = root.p.length * f }
                }
            }
            Item {
                anchors { right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                width: 76; height: 76
                scale: playTap.pressed ? 0.92 : 1
                Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                Cookie { anchors.fill: parent; color: MusicStore.accent; lobes: 9; amp: 0.07; spin: true; spinMs: 9000 }
                BarIcon { anchors.centerIn: parent; name: Playback.isPlaying ? "pause" : "play_arrow"; fill: 1; size: 36; color: MusicStore.onAccent }
                TapHandler { id: playTap; onTapped: Playback.toggle() }
            }
        }

        // where you listened last, as compact tiles
        Flow {
            width: parent.width; spacing: 10
            Repeater {
                model: MusicStore.quickTiles
                delegate: Rectangle {
                    id: qt
                    required property var modelData
                    readonly property bool playing: MusicStore.ctx?.id === modelData.item.id
                    width: root.width < 760 ? Math.floor((col.width - 10) / 2) : Math.floor((col.width - 30) / 4); height: 64; radius: 17
                    color: qtH.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 90 } }
                    scale: qtT.pressed ? 0.97 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
                    ClippingRectangle {
                        width: 64; height: 64; radius: 17; color: qt.modelData.kind === "liked" ? MusicStore.accent : BarStyle.plate
                        Image { visible: qt.modelData.kind !== "liked"; anchors.fill: parent; source: CoverCache.src(MusicStore.artOf(qt.modelData.item, false)); sourceSize: Qt.size(128, 128); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
                        BarIcon { visible: qt.modelData.kind === "liked"; anchors.centerIn: parent; name: "favorite"; fill: 1; size: 28; color: MusicStore.onAccent }
                    }
                    EText { x: 78; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; elide: Text.ElideRight; text: qt.modelData.item.name; font.weight: Font.DemiBold }
                    BarIcon { visible: qt.playing && Playback.isPlaying; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } name: "graphic_eq"; size: 20; color: MusicStore.accent }
                    HoverHandler { id: qtH }
                    TapHandler { id: qtT; onTapped: qt.modelData.kind === "liked" ? MusicStore.go("liked", null) : MusicStore.go(qt.modelData.kind, qt.modelData.item) }
                }
            }
        }

        Shelf { title: "Your playlists"; model: MusicStore.lists.filter(l => l).slice(0, 14); kind: "playlist"; order: 0 }
        Shelf { title: "Recently played"; model: MusicStore.recent; kind: "album"; order: 1 }
        Shelf { title: "Artists in your rotation"; model: MusicStore.topArtistsList; kind: "artist"; order: 2 }
        Shelf { title: "Albums from your listening"; model: MusicStore.topAlbums; kind: "album"; order: 3 }
    }
}
