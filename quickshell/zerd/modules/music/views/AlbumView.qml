import QtQuick
import qs.modules.bars
import qs.modules.music

Flickable {
    id: root
    property var album: MusicStore.arg
    property var tracks: []
    property var full: null
    contentHeight: head.height + tl.height + 100
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: MusicApi.album(root.album.id, (j, t) => { root.full = j; root.tracks = t })
    Header {
        id: head
        x: 34; y: 26; width: root.width - 68
        art: MusicStore.artOf(root.album, true)
        kind: root.full?.album_type === "single" ? "Single" : "Album"
        title: root.album?.name ?? ""
        subtitle: MusicStore.artistsOf(root.full ?? root.album) + "  ·  " + (root.full?.release_date ?? root.album?.release_date ?? "").slice(0, 4) + (root.tracks.length > 0 ? "  ·  " + root.tracks.length + " songs" : "")
        actions: [
            Pill { text: MusicStore.playingContext(root.album.uri) ? "Pause" : "Play"; icon: MusicStore.playingContext(root.album.uri) ? "pause" : "play_arrow"; onTapped: MusicStore.toggleContext(root.album.uri) }
        ]
    }
    TrackTable {
        id: tl
        x: 24; y: head.y + head.height + 12; width: root.width - 48
        tracks: root.tracks; context: root.album; showAlbum: false; showDate: false
    }
}
