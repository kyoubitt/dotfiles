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
    property real frac: 0
    Behavior on frac { NumberAnimation { duration: 220 } }
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
            const t0 = l[i]?.t ?? 0, t1 = l[i + 1]?.t ?? (t0 + 4)
            root.frac = t1 > t0 ? Math.max(0, Math.min(1, (root.pos - t0) / (t1 - t0))) : 0
        }
    }
    onLinesChanged: cur = 0

    function lineAt(i: int): string { return i >= 0 && i < lines.length ? lines[i].s : "" }

    Item {
        id: stage
        anchors.fill: parent
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
                delegate: Item {
                    id: ln
                    required property int index
                    readonly property int off: index - 2
                    readonly property string line: root.lineAt(root.cur + off)
                    width: col.width
                    height: base.height
                    opacity: off === 0 ? 1 : Math.max(0.15, 0.55 - Math.abs(off) * 0.2)
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    BarText {
                        id: base
                        width: parent.width
                        text: ln.line
                        elide: Text.ElideRight
                        color: ln.off === 0 ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.75)
                        style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.55)
                        font.pixelSize: ln.off === 0 ? 22 : 14
                        font.weight: ln.off === 0 ? Font.DemiBold : Font.Medium
                    }
                    // the line fills with the accent as it is sung
                    Item {
                        visible: ln.off === 0
                        width: Math.min(parent.width, base.implicitWidth) * root.frac
                        height: parent.height
                        clip: true
                        BarText {
                            width: ln.width
                            text: ln.line
                            elide: Text.ElideRight
                            color: BarStyle.accent
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.55)
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                    }
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
