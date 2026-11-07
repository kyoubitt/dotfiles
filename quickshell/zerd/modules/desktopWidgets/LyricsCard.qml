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
    // the sung line as a fractional position that glides to the new line: sizes, fades and the column all follow it, so nothing jumps
    property real fidx: cur
    Behavior on fidx { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    property real frac: 0
    readonly property int reach: Math.max(2, Math.min(5, Math.round(height / 80)))      // lines shown each side: a bigger card shows more lines, not bigger letters
    property real base: 0               // the player's last answer, in seconds
    property real stamp: 0              // when that answer arrived
    readonly property bool ready: LyricsStore.state === "ok" && lines.length > 0

    onTitleChanged: if (title.length > 0) LyricsStore.request(title, artist, p?.length ?? 0)
    Component.onCompleted: if (title.length > 0) LyricsStore.request(title, artist, p?.length ?? 0)

    // Ask the player where it is twice a second, and keep time between answers on our own clock, so the words follow
    // smoothly instead of waiting for the next answer.
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true; running: root.widget.powerActive && root.ready
        onTriggered: { if (root.p) { root.p.positionChanged(); root.base = root.p.position; root.stamp = Date.now() } }
    }
    Timer {
        interval: 40; repeat: true; running: root.widget.powerActive && root.ready
        onTriggered: {
            root.pos = root.base + (root.playing ? (Date.now() - root.stamp) / 1000 : 0)
            const l = root.lines
            let i = 0
            for (let k = 0; k < l.length; k++) { if (l[k].t >= 0 && l[k].t <= root.pos + 0.12) i = k; else if (l[k].t > root.pos) break }
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
        // Every line is built once and only moves: a line change shrinks the one just sung and grows the next, and the
        // whole column follows. Nothing is laid out again, so the change costs a few transforms, not ten text layouts.
        readonly property int i0: Math.max(0, Math.min(rep.count - 1, Math.floor(root.fidx)))
        readonly property real fr: Math.max(0, Math.min(1, root.fidx - i0))
        readonly property Item itemA: rep.count > 0 ? rep.itemAt(i0) : null
        readonly property Item itemB: rep.count > 0 ? rep.itemAt(Math.min(rep.count - 1, i0 + 1)) : null
        // the column keeps the sung position at the middle, between the centres of the two lines it is gliding between
        readonly property real centreY: (itemA ? itemA.y + itemA.height / 2 : 0) * (1 - fr) + (itemB ? itemB.y + itemB.height / 2 : 0) * fr
        Column {
            id: col
            width: parent.width
            spacing: 8
            y: stage.height / 2 - stage.centreY
            Repeater {
                id: rep
                model: root.lines.length
                delegate: Item {
                    id: ln
                    required property int index
                    readonly property real dist: Math.abs(index - root.fidx)
                    readonly property bool sel: index === root.cur
                    readonly property string line: root.lines[index]?.s ?? ""
                    readonly property real k: Math.max(0.64, 1 - dist * 0.36)
                    width: col.width
                    height: base.height * k
                    opacity: (dist <= 1 ? 1 - dist * 0.57 : Math.max(0.15, 0.43 - (dist - 1) * 0.12)) * Math.max(0, Math.min(1, root.reach + 1 - dist))
                    Item {
                        width: col.width; height: base.height
                        scale: ln.k; transformOrigin: Item.TopLeft
                        BarText {
                            id: base
                            width: parent.width
                            text: ln.line
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            // not yet sung: a quieter white; the sung part is solid white over it
                            color: Qt.rgba(1, 1, 1, ln.sel ? 0.5 : 0.78)
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                        }
                        // the sung part, row by row: the first row fills first, then the second; only the line being sung has it
                        Loader {
                            active: ln.sel
                            sourceComponent: Item {
                                Repeater {
                                    model: Math.max(1, base.lineCount)
                                    delegate: Item {
                                        id: row
                                        required property int index
                                        readonly property real rowH: base.height / Math.max(1, base.lineCount)
                                        readonly property real part: Math.max(0, Math.min(1, root.frac * base.lineCount - index))
                                        x: 0; y: index * rowH
                                        width: Math.round(base.width * part); height: rowH
                                        clip: true
                                        BarText {
                                            y: -row.y
                                            width: base.width
                                            text: ln.line
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            color: "#ffffff"
                                            font.pixelSize: 22
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
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
