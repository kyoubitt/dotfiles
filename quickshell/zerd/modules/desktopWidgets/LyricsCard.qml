import QtQuick
import qs.services
import qs.modules.bars
import qs.modules.music
import qs.modules.iris.widgets

// The words of the song that is playing: the line being sung big, the ones around it faint, sliding up as it goes.
IrisWidgetFace {
    id: root

    readonly property var p: NowPlaying.player
    readonly property bool playing: NowPlaying.isPlaying
    readonly property string title: p?.trackTitle ?? ""
    readonly property string artist: p?.trackArtist ?? ""
    readonly property var lines: LyricsStore.lines
    property real pos: 0
    property int cur: 0
    readonly property bool ready: LyricsStore.state === "ok" && lines.length > 0

    onTitleChanged: if (title.length > 0) LyricsStore.request(title, artist, p?.length ?? 0)
    Component.onCompleted: if (title.length > 0) LyricsStore.request(title, artist, p?.length ?? 0)
    Timer {
        interval: 200; repeat: true; running: root.widget.powerActive && root.playing && root.ready
        onTriggered: {
            if (root.p) { root.p.positionChanged(); root.pos = root.p.position }
            const l = root.lines
            let i = 0
            for (let k = 0; k < l.length; k++) { if (l[k].t >= 0 && l[k].t <= root.pos + 0.25) i = k; else if (l[k].t > root.pos) break }
            if (i !== root.cur) root.cur = i
        }
    }
    onLinesChanged: cur = 0

    function lineAt(i: int): string { return i >= 0 && i < lines.length ? lines[i].s : "" }

    // header
    Row {
        id: head
        anchors { left: parent.left; top: parent.top }
        spacing: 8
        BarIcon { name: "lyrics"; size: 16; color: BarStyle.accent; anchors.verticalCenter: parent.verticalCenter }
        BarText {
            width: root.width - root.padding * 2 - 24
            text: root.title.length > 0 ? root.title + (root.artist ? "  ·  " + root.artist : "") : "Lyrics"
            color: BarStyle.subtext; font.pixelSize: 12; elide: Text.ElideRight
        }
    }

    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 8 }
        clip: true
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        // five lines; the middle one is the one being sung
        Column {
            id: col
            width: parent.width
            y: Math.round((stage.height - height) / 2) - 0
            spacing: 6
            Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Repeater {
                model: 5
                delegate: BarText {
                    required property int index
                    readonly property int off: index - 2
                    width: col.width
                    text: root.lineAt(root.cur + off)
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    color: off === 0 ? BarStyle.text : BarStyle.subtext
                    opacity: off === 0 ? 1 : Math.max(0.15, 0.55 - Math.abs(off) * 0.2)
                    font.pixelSize: off === 0 ? 22 : 14
                    font.weight: off === 0 ? Font.DemiBold : Font.Medium
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }
            }
        }
    }
    BarText {
        anchors.centerIn: stage
        visible: !root.ready
        text: root.title.length === 0 ? "Nothing playing" : LyricsStore.state === "loading" ? "Finding the words…" : "No lyrics for this song"
        color: BarStyle.subtext; font.pixelSize: 14
    }
}
