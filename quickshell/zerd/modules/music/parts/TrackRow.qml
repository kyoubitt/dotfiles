import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.bars
import qs.modules.music

// One song in a list. Click plays it (inside its playlist or album when it has one). Hover brings queue, add to a
// playlist and the trash bin.
Item {
    id: root
    required property var track
    property var context: null            // the playlist/album it sits in, so play carries on down the list
    property int number: -1               // show "1, 2, 3" instead of art when set
    property bool showAlbum: false
    property bool showDate: false
    // column geometry (set by TrackTable so the rows line up with the header)
    property real titleX: 62
    property real titleW: showAlbum ? width * 0.42 : width - 220
    property real albumX: width * 0.42 + 80
    property real albumW: width * 0.3
    property real dateX: 0
    property real dateW: 0
    property bool custom: false           // the table plays it (it knows the sorted order)
    signal chosen()
    width: ListView.view ? ListView.view.width : 400
    height: 56

    readonly property bool current: (Playback.player?.trackTitle ?? "") === (track?.name ?? "#") && Playback.isPlaying
    Rectangle { anchors.fill: parent; radius: 16; color: hov.hovered ? BarStyle.plateHover : "transparent"; Behavior on color { ColorAnimation { duration: 90 } } }

    Item {
        x: 10; width: 40; height: parent.height
        EText { visible: root.number >= 0 && !root.current && !hov.hovered; anchors.centerIn: parent; text: root.number; color: BarStyle.subtext }
        BarIcon { visible: root.current; anchors.centerIn: parent; name: "graphic_eq"; size: 20; color: MusicStore.accent }
        BarIcon { visible: root.number >= 0 && hov.hovered && !root.current; anchors.centerIn: parent; name: "play_arrow"; fill: 1; size: 22; color: BarStyle.text }
        ClippingRectangle {
            visible: root.number < 0; anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42; radius: 10; color: BarStyle.plate
            Image { anchors.fill: parent; source: MusicStore.artOf(root.track, false); sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: false }
        }
    }
    Column {
        x: root.titleX; anchors.verticalCenter: parent.verticalCenter; width: root.titleW; spacing: 2
        EText { width: parent.width; elide: Text.ElideRight; text: root.track?.name ?? ""; font.weight: Font.Medium; color: root.current ? MusicStore.accent : BarStyle.text }
        EText { width: parent.width; elide: Text.ElideRight; text: MusicStore.artistsOf(root.track); font.pixelSize: 12; color: BarStyle.subtext }
    }
    EText {
        visible: root.showAlbum; x: root.albumX; width: root.albumW; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; text: root.track?.album?.name ?? ""; font.pixelSize: 13; color: BarStyle.subtext
    }
    Row {
        visible: hov.hovered
        anchors { right: parent.right; rightMargin: 56; verticalCenter: parent.verticalCenter }
        spacing: 2
        Repeater {
            model: [{ i: "queue_music", t: "q" }, { i: "playlist_add", t: "p" }, { i: "block", t: "t" }]
            delegate: Rectangle {
                id: ab
                required property var modelData
                width: 34; height: 34; radius: 17; color: abHov.hovered ? BarStyle.border : "transparent"
                BarIcon { anchors.centerIn: parent; name: ab.modelData.i; size: 19; color: BarStyle.text }
                HoverHandler { id: abHov }
                TapHandler { onTapped: {
                    if (ab.modelData.t === "q") { MusicApi.queue(root.track.uri); MusicStore.tell("Added to the queue") }
                    else if (ab.modelData.t === "p") MusicStore.pickTrack = root.track
                    else MusicStore.toTrash(root.track)
                } }
            }
        }
    }
    EText {
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        text: { const s = Math.round((root.track?.duration_ms ?? 0) / 1000); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }
        font.pixelSize: 12; color: BarStyle.subtext
    }
    EText {
        visible: root.showDate; x: root.dateX; width: root.dateW; anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight; font.pixelSize: 13; color: BarStyle.subtext
        text: root.track?.added_at ? Qt.formatDate(new Date(root.track.added_at), "MMM d, yyyy") : ""
    }
    HoverHandler { id: hov }
    TapHandler { onTapped: root.custom ? root.chosen() : root.context ? MusicApi.play(root.context.uri, true, root.track.uri) : MusicApi.play(root.track.uri, false, "") }
}
