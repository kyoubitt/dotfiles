import QtQuick
import qs.modules.bars
import qs.modules.music

// All your playlists as a grid.
Flickable {
    id: root
    contentHeight: grid.height + 100
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    EText { x: 34; y: 26; text: "Your playlists"; font.pixelSize: 32; font.weight: Font.Bold }
    Flow {
        id: grid
        x: 24; y: 90; width: root.width - 48; spacing: 6
        Repeater { model: MusicStore.lists.filter(l => l); delegate: Card { required property var modelData; item: modelData; kind: "playlist" } }
    }
}
