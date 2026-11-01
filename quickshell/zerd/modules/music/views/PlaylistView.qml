import QtQuick
import qs.modules.bars
import qs.modules.music

// A playlist: the header with its buttons, then every song.
Flickable {
    id: root
    property var list: MusicStore.arg
    property var tracks: []
    property var info: null
    contentHeight: head.height + tl.height + 100
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: {
        MusicApi.playlist(root.list.id, j => root.info = j)
        MusicApi.playlistItems(root.list.id, t => root.tracks = t, t => root.tracks = t)
    }
    Header {
        id: head
        x: 34; y: 26; width: root.width - 68
        art: MusicStore.artOf(root.info ?? root.list, true)
        kind: "Playlist"
        title: root.list?.name ?? ""
        subtitle: (root.info?.owner?.display_name ?? root.list?.owner?.display_name ?? "") + (root.tracks.length > 0 ? "  ·  " + root.tracks.length + " songs" : "")
        actions: [
            Pill { text: MusicStore.playingContext(root.list.uri) ? "Pause" : "Play"; icon: MusicStore.playingContext(root.list.uri) ? "pause" : "play_arrow"; onTapped: MusicStore.toggleContext(root.list.uri) },
            Pill { text: "Shuffle+"; icon: "shuffle"; filled: false; onTapped: MusicStore.shufflePlus(root.list) },
            Pill { text: MusicStore.isPinned(root.list.id) ? "Unpin" : "Pin"; icon: "keep"; filled: false; onTapped: MusicStore.togglePin(root.list.id) }
        ]
    }
    TrackTable {
        id: tl
        x: 24; y: head.y + head.height + 12; width: root.width - 48
        tracks: root.tracks; context: root.list; showAlbum: true; showDate: true
    }
}
