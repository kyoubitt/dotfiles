import QtQuick
import qs.modules.bars
import qs.modules.music

// Search: the box lives in the top bar; results come in as you type, with chips to narrow them.
Flickable {
    id: root
    property var results: null
    property string chip: "all"
    contentHeight: col.implicitHeight + 70
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Timer { id: deb; interval: 260; onTriggered: { const q = MusicStore.query.trim(); if (q.length > 1) MusicApi.search(q, r => { if (MusicStore.query.trim() === q) root.results = r }); else root.results = null } }
    Connections { target: MusicStore; function onQueryChanged() { deb.restart() } }
    Component.onCompleted: deb.restart()

    readonly property var tracks: (results?.tracks?.items ?? []).filter(x => x)
    readonly property var artists: (results?.artists?.items ?? []).filter(x => x)
    readonly property var albums: (results?.albums?.items ?? []).filter(x => x)
    readonly property var lists: (results?.playlists?.items ?? []).filter(x => x)

    Column {
        id: col
        x: 34; y: 26; width: root.width - 68; spacing: 14
        EText { visible: root.results?.local === true; text: "Spotify is limiting requests: searching only what is saved on this computer"; font.pixelSize: 12; color: BarStyle.subtext }
        Row {
            spacing: 8
            Repeater {
                model: [{ v: "all", l: "All" }, { v: "songs", l: "Songs" }, { v: "artists", l: "Artists" }, { v: "albums", l: "Albums" }, { v: "playlists", l: "Playlists" }]
                delegate: Rectangle {
                    id: ch
                    required property var modelData
                    readonly property bool on: root.chip === modelData.v
                    width: chText.implicitWidth + 30; height: 36; radius: 18
                    color: on ? MusicStore.accent : (chHov.hovered ? BarStyle.plateHover : "transparent"); border.width: on ? 0 : 1; border.color: BarStyle.border
                    Behavior on color { ColorAnimation { duration: 90 } }
                    EText { id: chText; anchors.centerIn: parent; text: ch.modelData.l; font.weight: Font.Medium; color: ch.on ? MusicStore.onAccent : BarStyle.text }
                    HoverHandler { id: chHov }
                    TapHandler { onTapped: root.chip = ch.modelData.v }
                }
            }
        }
        EText { visible: MusicStore.query.trim().length < 2; text: MusicStore.searchHistory.length > 0 ? "Recent searches" : "Type in the search box up top"; font.weight: Font.DemiBold; color: BarStyle.subtext; topPadding: 24 }
        Flow {
            visible: MusicStore.query.trim().length < 2 && MusicStore.searchHistory.length > 0
            width: parent.width; spacing: 8
            Repeater {
                model: MusicStore.searchHistory
                delegate: Rectangle {
                    id: hc
                    required property string modelData
                    width: hcText.implicitWidth + 36; height: 36; radius: 18
                    color: hch.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Row { anchors.centerIn: parent; spacing: 8
                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "history"; size: 16; color: BarStyle.subtext }
                        EText { id: hcText; anchors.verticalCenter: parent.verticalCenter; text: hc.modelData; font.pixelSize: 13 } }
                    HoverHandler { id: hch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: MusicStore.query = hc.modelData }
                }
            }
        }
        EText { visible: MusicStore.query.trim().length < 2 && MusicStore.searchHistory.length > 0; text: "Clear history"; font.pixelSize: 12; color: BarStyle.subtext; TapHandler { onTapped: MusicStore.clearHistory() } }
        // the best match
        Rectangle {
            visible: root.chip === "all" && root.tracks.length > 0
            width: Math.min(420, parent.width); height: 130; radius: 26; color: BarStyle.plate; border.width: 1; border.color: BarStyle.border
            EText { x: 22; y: 16; text: "Top result"; font.pixelSize: 12; color: BarStyle.subtext }
            EText { x: 22; y: 44; width: parent.width - 44; elide: Text.ElideRight; text: root.tracks[0]?.name ?? ""; font.pixelSize: 22; font.weight: Font.Bold }
            EText { x: 22; y: 76; width: parent.width - 44; elide: Text.ElideRight; text: MusicStore.artistsOf(root.tracks[0]); color: BarStyle.subtext }
            TapHandler { onTapped: MusicApi.play(root.tracks[0].uri, false, "") }
        }
        EText { visible: (root.chip === "all" || root.chip === "songs") && root.tracks.length > 0; text: "Songs"; font.pixelSize: 21; font.weight: Font.DemiBold }
        ListView {
            visible: (root.chip === "all" || root.chip === "songs") && root.tracks.length > 0
            width: parent.width + 20; x: -10; height: contentHeight; interactive: false
            model: root.chip === "songs" ? root.tracks : root.tracks.slice(0, 5)
            delegate: TrackRow { required property var modelData; track: modelData }
        }
        Shelf { visible: (root.chip === "all" || root.chip === "artists") && root.artists.length > 0; title: "Artists"; model: root.artists; kind: "artist" }
        Shelf { visible: (root.chip === "all" || root.chip === "albums") && root.albums.length > 0; title: "Albums"; model: root.albums; kind: "album" }
        Shelf { visible: (root.chip === "all" || root.chip === "playlists") && root.lists.length > 0; title: "Playlists"; model: root.lists; kind: "playlist" }
    }
}
