import QtQuick
import Quickshell.Widgets
import qs.modules.bars
import qs.modules.music

// For a narrow window: the right-hand panel becomes just the words, in a slim card with the song's name on top.
// The sung line is lit and tapping a line jumps the song to it.
Rectangle {
    id: root
    width: 300
    radius: 24
    color: Qt.rgba(0, 0, 0, 0.34)
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)

    property real pos: 0
    Timer {
        interval: 150; repeat: true; running: root.visible
        onTriggered: { const p = Playback.player; if (p) { p.positionChanged(); root.pos = p.position } }
    }
    Connections { target: MusicStore; function onTrackKeyChanged() { root.pos = 0 } }

    // what is playing, on top: the cover, the name, the artist and where it plays from
    Item {
        id: head
        x: 16; y: 16; width: parent.width - 32; height: 84
        ClippingRectangle {
            width: 80; height: 80; radius: 18; color: BarStyle.plate
            Image { anchors.fill: parent; source: CoverCache.src(Playback.player?.trackArtUrl ?? ""); sourceSize: Qt.size(120, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
        }
        Column {
            x: 94; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 94; spacing: 3
            BarMarquee { width: parent.width; height: 26; text: Playback.player?.trackTitle ?? "Nothing playing"; weight: Font.Bold; pixelSize: 19 }
            BarMarquee { width: parent.width; height: 20; text: Playback.player?.trackArtist ?? ""; pixelSize: 15; weight: Font.Normal; color: BarStyle.subtext }
            EText { visible: (MusicStore.ctx?.name ?? "").length > 0; width: parent.width; elide: Text.ElideRight; text: MusicStore.ctx?.name ?? ""; font.pixelSize: 13; color: MusicStore.accent }
        }
    }
    LyricsView {
        x: 10; y: 112; width: parent.width - 20; height: parent.height - 124
        size: 20; tools: false
        position: root.pos
        onSeekTo: t => { const p = Playback.player; if (p) p.position = t }
    }
}
