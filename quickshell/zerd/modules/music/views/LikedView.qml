import QtQuick
import qs.modules.bars
import qs.modules.music

// Your Liked Songs (the newest 300).
Flickable {
    id: root
    property var tracks: []
    property int total: 0
    contentHeight: head.height + tl.height + 100
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: MusicApi.liked((t, n) => { root.tracks = t; root.total = n })
    Header {
        id: head
        x: 34; y: 26; width: root.width - 68
        kind: "Playlist"; icon: "favorite"; title: "Liked Songs"; subtitle: root.total > 0 ? root.total + " songs" : ""
        actions: [ Pill { text: "Play"; icon: "play_arrow"; onTapped: MusicApi.playUris(root.tracks.map(t => t.uri)) } ]
    }
    TrackTable {
        id: tl
        x: 24; y: head.y + head.height + 12; width: root.width - 48
        tracks: root.tracks; showAlbum: true; showDate: false
    }
}
