import QtQuick
import qs.modules.bars
import qs.modules.music

Flickable {
    id: root
    property var artist: MusicStore.arg
    property var topSongs: []
    property var albums: []
    property var full: null
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Component.onCompleted: {
        MusicApi.artist(root.artist.id, j => root.full = j)
        MusicApi.artistTop(root.artist.id, t => {
            if (t) root.topSongs = t
            else MusicApi.search("artist:\"" + root.artist.name + "\"", r => root.topSongs = (r?.tracks?.items ?? []).filter(x => x).slice(0, 8))
        })
        MusicApi.artistAlbums(root.artist.id, a => root.albums = a)
    }
    Column {
        id: col
        x: 34; y: 26; width: root.width - 68; spacing: 14
        Header {
            art: MusicStore.artOf(root.full ?? root.artist, true); round: true; kind: "Artist"; title: root.artist?.name ?? ""
            subtitle: root.full?.followers ? Number(root.full.followers.total).toLocaleString(Qt.locale(), "f", 0) + " followers" : ""
            actions: [ Pill { text: MusicStore.playingContext(root.artist.uri) ? "Pause" : "Play"; icon: MusicStore.playingContext(root.artist.uri) ? "pause" : "play_arrow"; onTapped: MusicStore.toggleContext(root.artist.uri) } ]
        }
        EText { visible: root.topSongs.length > 0; text: "Popular"; font.pixelSize: 21; font.weight: Font.DemiBold; topPadding: 6 }
        ListView {
            id: tl
            width: parent.width + 20; x: -10; height: contentHeight; interactive: false
            model: root.topSongs.slice(0, 8)
            delegate: TrackRow { required property var modelData; required property int index; track: modelData; number: index + 1 }
        }
        Shelf { title: "Albums and singles"; model: root.albums; kind: "album" }
    }
}
