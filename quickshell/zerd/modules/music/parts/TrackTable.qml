import QtQuick
import qs.modules.bars
import qs.modules.music

// A song list like Spotify's: a header with the columns (click one to sort by it), a filter box, and rows that line
// up with it. Used by playlists, albums and Liked Songs.
Column {
    id: root
    property var tracks: []
    property var context: null           // the playlist or album, so play continues down the list
    property bool showAlbum: true
    property bool showDate: false
    property string sortKey: ""          // "" | title | album | date | dur
    property int dir: 1
    property string filter: ""
    width: parent ? parent.width : 800
    spacing: 0

    readonly property var rows: {
        let out = root.tracks.slice()
        const q = root.filter.trim().toLowerCase()
        if (q.length > 0) out = out.filter(t => (t.name + " " + MusicStore.artistsOf(t) + " " + (t.album?.name ?? "")).toLowerCase().includes(q))
        const k = root.sortKey, d = root.dir
        if (k === "title") out.sort((a, b) => d * a.name.localeCompare(b.name))
        else if (k === "album") out.sort((a, b) => d * (a.album?.name ?? "").localeCompare(b.album?.name ?? ""))
        else if (k === "date") out.sort((a, b) => d * String(a.added_at ?? "").localeCompare(String(b.added_at ?? "")))
        else if (k === "dur") out.sort((a, b) => d * ((a.duration_ms ?? 0) - (b.duration_ms ?? 0)))
        return out
    }

    // column geometry shared by the header and every row
    readonly property real titleX: 66
    readonly property real durW: 72
    readonly property real avail: Math.max(200, width - titleX - durW - 24)
    readonly property real titleW: showAlbum && showDate ? (avail - 32) * 0.42 : (showAlbum ? (avail - 16) * 0.6 : avail)
    readonly property real albumW: showAlbum && showDate ? (avail - 32) * 0.30 : (showAlbum ? (avail - 16) * 0.4 : 0)
    readonly property real dateW: showAlbum && showDate ? (avail - 32) * 0.28 : 0
    readonly property real albumX: titleX + titleW + 16
    readonly property real dateX: albumX + albumW + 16

    // filter
    Item {
        width: parent.width; height: 58
        Rectangle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: filterBox.activeFocus || root.filter.length > 0 ? 280 : 44; height: 40; radius: 23
            color: Qt.rgba(1, 1, 1, 0.09); border.width: 1; border.color: filterBox.activeFocus ? MusicStore.accent : "transparent"
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            BarIcon { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; color: BarStyle.subtext }
            TextInput { id: filterBox; x: 40; width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter; color: BarStyle.text; font.pixelSize: 14; clip: true; selectByMouse: true
                text: root.filter; onTextChanged: root.filter = text; Keys.onEscapePressed: { text = ""; focus = false } }
            EText { x: 40; anchors.verticalCenter: parent.verticalCenter; visible: filterBox.text.length === 0 && parent.width > 100; text: "Filter this list"; font.pixelSize: 14; color: BarStyle.subtext }
            TapHandler { onTapped: filterBox.forceActiveFocus() }
        }
    }

    // header row
    Item {
        id: head
        width: parent.width; height: 40
        component Col: Item {
            id: col
            property string label
            property string key
            property alias hAlign: txt.horizontalAlignment
            height: head.height
            readonly property bool on: root.sortKey === key
            EText { id: txt; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20; elide: Text.ElideRight; text: col.label
                font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.6; color: col.on ? MusicStore.accent : BarStyle.subtext }
            BarIcon { visible: col.on; anchors { right: parent.right; verticalCenter: parent.verticalCenter } name: root.dir > 0 ? "arrow_upward" : "arrow_downward"; size: 15; color: MusicStore.accent }
            TapHandler { onTapped: { if (root.sortKey === col.key) { if (root.dir > 0) root.dir = -1; else { root.sortKey = ""; root.dir = 1 } } else { root.sortKey = col.key; root.dir = 1 } } }
        }
        EText { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "#"; font.pixelSize: 13; color: BarStyle.subtext }
        Col { x: root.titleX; width: root.titleW; label: "TITLE"; key: "title" }
        Col { visible: root.showAlbum; x: root.albumX; width: root.albumW; label: "ALBUM"; key: "album" }
        Col { visible: root.showAlbum && root.showDate; x: root.dateX; width: root.dateW; label: "DATE ADDED"; key: "date" }
        Col { anchors.right: parent.right; anchors.rightMargin: 16; width: 56; label: ""; key: "dur"; hAlign: Text.AlignRight
            BarIcon { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: "schedule"; size: 18; color: root.sortKey === "dur" ? MusicStore.accent : BarStyle.subtext } }
    }
    Rectangle { width: parent.width - 24; x: 12; height: 1; color: Qt.rgba(1, 1, 1, 0.12) }
    Item { width: 1; height: 8 }

    ListView {
        id: list
        width: parent.width; height: contentHeight; interactive: false
        model: root.rows
        delegate: TrackRow {
            required property var modelData
            required property int index
            track: modelData; number: index + 1
            showAlbum: root.showAlbum; showDate: root.showDate
            titleX: root.titleX; titleW: root.titleW; albumX: root.albumX; albumW: root.albumW; dateX: root.dateX; dateW: root.dateW
            context: root.context
            custom: root.sortKey !== "" || root.filter.length > 0
            onChosen: MusicApi.playUris(root.rows.slice(index).map(t => t.uri))
        }
    }
    EText { visible: root.rows.length === 0 && root.tracks.length > 0; x: 20; topPadding: 20; text: "Nothing matches"; color: BarStyle.subtext }
}
