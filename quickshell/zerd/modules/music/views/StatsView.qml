import QtQuick
import qs.modules.bars
import qs.modules.music

// What you play most, from your Spotify account (4 weeks, 6 months, all time).
Flickable {
    id: root
    property string range: "short_term"
    property var artists: []
    property var tracks: []
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    function load(): void { MusicApi.topArtists(root.range, r => root.artists = r); MusicApi.topTracks(root.range, r => root.tracks = r) }
    onRangeChanged: load()
    Component.onCompleted: load()
    Column {
        id: col
        x: 34; y: 26; width: root.width - 68; spacing: 14
        Row {
            spacing: 8
            EText { anchors.verticalCenter: parent.verticalCenter; text: "Your stats"; font.pixelSize: 32; font.weight: Font.Bold; rightPadding: 18 }
            Repeater {
                model: [{ v: "short_term", l: "4 weeks" }, { v: "medium_term", l: "6 months" }, { v: "long_term", l: "All time" }]
                delegate: Rectangle {
                    id: rg
                    required property var modelData
                    readonly property bool on: root.range === modelData.v
                    anchors.verticalCenter: parent.verticalCenter
                    width: rgText.implicitWidth + 30; height: 36; radius: 23
                    color: on ? MusicStore.accent : (rgHov.hovered ? BarStyle.plateHover : "transparent"); border.width: on ? 0 : 1; border.color: BarStyle.border
                    Behavior on color { ColorAnimation { duration: 90 } }
                    EText { id: rgText; anchors.centerIn: parent; text: rg.modelData.l; font.weight: Font.Medium; color: rg.on ? MusicStore.onAccent : BarStyle.text }
                    HoverHandler { id: rgHov }
                    TapHandler { onTapped: root.range = rg.modelData.v }
                }
            }
        }
        Row {
            spacing: 12
            Repeater {
                model: [{ i: "person", t: "Top artist", v: root.artists[0]?.name ?? "—" }, { i: "music_note", t: "Top song", v: root.tracks[0]?.name ?? "—" }, { i: "album", t: "Top album", v: root.tracks[0]?.album?.name ?? "—" }]
                delegate: Rectangle {
                    id: hd
                    required property var modelData
                    width: Math.floor((col.width - 24) / 3); height: 112; radius: 30; color: BarStyle.plate; border.width: 1; border.color: BarStyle.border
                    Cookie { x: 18; y: 16; width: 44; height: 44; color: Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.25); lobes: 8; amp: 0.08 }
                    BarIcon { x: 29; y: 27; name: hd.modelData.i; size: 22; color: MusicStore.accent }
                    EText { x: 18; y: 68; text: hd.modelData.t; font.pixelSize: 12; color: BarStyle.subtext }
                    EText { x: 18; y: 84; width: parent.width - 36; elide: Text.ElideRight; text: hd.modelData.v; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
            }
        }
        Shelf { title: "Top artists"; model: root.artists; kind: "artist" }
        EText { text: "Top songs"; font.pixelSize: 21; font.weight: Font.DemiBold }
        ListView { width: parent.width + 20; x: -10; height: contentHeight; interactive: false; model: root.tracks.slice(0, 15)
            delegate: TrackRow { required property var modelData; required property int index; track: modelData; number: index + 1; showAlbum: true } }
    }
}
