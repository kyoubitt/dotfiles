import QtQuick
import QtQuick.Effects
import qs.modules.bars
import qs.modules.music

// The words, large, with the line being sung lit. The current line sits in the middle of a soft pill with a glow
// under it; when the song moves to the next line every line eases into place one after another, so the list waves.
Item {
    id: root
    property real position: 0                 // seconds into the song
    property color glow: MusicStore.accent
    property real size: 32               // text size of the line being sung (A- / A+)
    property bool tools: true            // the little size / timing buttons in the corner
    property real offset: 0              // seconds: nudge when a song's lyrics run early or late
    signal seekTo(real seconds)

    readonly property var lines: LyricsStore.lines
    readonly property bool synced: LyricsStore.synced

    // the line being sung: the last one that has started (a binary search over the start times)
    readonly property int active: {
        if (!root.synced || root.lines.length === 0) return -1
        let lo = 0, hi = root.lines.length - 1, at = -1
        const p = root.position + root.offset + 0.2
        while (lo <= hi) { const mid = (lo + hi) >> 1; if (root.lines[mid].t <= p) { at = mid; lo = mid + 1 } else hi = mid - 1 }
        return at
    }
    property int shown: -1
    signal stepped(int delta)
    onActiveChanged: { if (root.active >= 0) { const d = root.active - root.shown; root.shown = root.active; if (root.shown >= 0 && Math.abs(d) <= 3) root.stepped(d) ; follow() } }
    function follow(): void {
        const it = list.itemAtIndex(Math.max(0, root.active))
        if (!it) { list.positionViewAtIndex(Math.max(0, root.active), ListView.Center); return }
        followAnim.to = Math.max(0, Math.min(list.contentHeight - list.height, it.y + it.height / 2 - list.height / 2))
        followAnim.restart()
    }
    NumberAnimation { id: followAnim; target: list; property: "contentY"; duration: 420; easing.type: Easing.OutCubic }

    // an edge fade at the top and bottom
    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true; maskSource: fade; maskThresholdMin: 0.0; maskSpreadAtMin: 0.0
    }
    Item {
        id: fade; anchors.fill: parent; visible: false; layer.enabled: true
        Rectangle { anchors.fill: parent; gradient: Gradient {
            GradientStop { position: 0; color: "#00000000" }
            GradientStop { position: 0.09; color: "#ff000000" }
            GradientStop { position: 0.91; color: "#ff000000" }
            GradientStop { position: 1; color: "#00000000" } } }
    }

    // the pill behind the line being sung
    Rectangle {
        id: pill
        visible: root.synced && root.active >= 0
        property Item cur: list.itemAtIndex(Math.max(0, root.active))
        x: 0; width: parent.width
        y: cur ? cur.y - list.contentY - 6 : 0
        height: cur ? cur.height + 12 : 0
        radius: 30
        color: Qt.rgba(root.glow.r, root.glow.g, root.glow.b, 0.16)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 600 } }
        // it stretches a little while it moves to the next line, then settles
        Behavior on height { SpringAnimation { spring: 5; damping: 0.38; mass: 0.8 } }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: false
        model: root.lines
        spacing: 22
        cacheBuffer: 4000
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.synced
        topMargin: root.synced ? height / 2 : 40
        bottomMargin: root.synced ? height / 2 : 40
        delegate: Item {
            id: ln
            required property var modelData
            required property int index
            width: ListView.view.width
            height: Math.max(label.implicitHeight, 22) + 8
            readonly property bool cur: root.synced ? index === root.active : true
            property real lag: 0
            readonly property real dist: root.synced && root.active >= 0 ? Math.abs(index - root.active) : 0

            Connections {
                target: root
                function onStepped(d) {
                    ln.lag = d * 22
                    ripple.restart()
                }
            }
            SequentialAnimation {
                id: ripple
                PauseAnimation { duration: Math.min(ln.dist, 8) * 16 }
                NumberAnimation { target: ln; property: "lag"; to: 0; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
            }

            EText {
                id: label
                x: 18; width: parent.width - 36
                y: 4 + ln.lag + (ln.cur && root.synced ? -4 : 0)
                Behavior on y { enabled: !ripple.running; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                visible: ln.modelData.s.length > 0
                text: ln.modelData.s.length > 0 ? ln.modelData.s : "♪"
                wrapMode: Text.WordWrap
                color: (root.synced && ln.cur) ? "#8cffffff" : "#ffffff"
                font.pixelSize: root.synced ? root.size : root.size * 0.75
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                opacity: !root.synced ? 0.9 : (ln.cur ? 1 : Math.max(0.16, 0.34 - ln.dist * 0.02))
                scale: !root.synced ? 1 : (ln.cur ? 1.06 : Math.max(0.88, 0.94 - ln.dist * 0.01))
                transformOrigin: Item.Left
                Behavior on opacity { NumberAnimation { duration: 260 } }
                Behavior on scale { SpringAnimation { spring: 4; damping: 0.42 } }
                // the sung line glows, lines two or more away fall out of focus
                property real soft: root.synced && !ln.cur && ln.dist >= 2 ? Math.min(0.6, (ln.dist - 1) * 0.15) : 0
                Behavior on soft { NumberAnimation { duration: 260 } }
                layer.enabled: root.synced && (ln.cur || soft > 0.01)
                layer.effect: MultiEffect {
                    shadowEnabled: ln.cur; shadowColor: root.glow; shadowOpacity: 0.55; shadowBlur: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                    blurEnabled: label.soft > 0.01; blur: label.soft; blurMax: 24
                }
                // the line fills with light as it is sung, one wrapped row after the other. These rows are children of the
                // label itself, so they share its position, scale and glow exactly and can never drift off it.
                Repeater {
                    model: ln.cur && root.synced ? Math.max(1, label.lineCount) : 0
                    delegate: Item {
                        id: row
                        required property int index
                        readonly property real f: Math.max(0, Math.min(1, (root.position + root.offset - ln.modelData.t) / Math.max(1.2, ln.nextT - ln.modelData.t)))
                        readonly property int n: Math.max(1, label.lineCount)
                        readonly property real rh: label.height / n
                        x: 0; y: index * rh; height: rh
                        width: label.width * Math.max(0, Math.min(1, f * n - index))
                        clip: true
                        EText { y: -row.index * row.rh; width: label.width; height: label.height; text: label.text; wrapMode: Text.WordWrap; color: "#ffffff"; font.pixelSize: label.font.pixelSize; font.weight: Font.Bold }
                    }
                }
            }
            // a gap with no words: three dots that light one after the other
            Row {
                visible: ln.modelData.s.length === 0 && root.synced
                x: 18; y: 4 + ln.lag; height: label.implicitHeight; spacing: 10
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        readonly property real f: ln.cur ? Math.max(0, Math.min(1, (root.position + root.offset - ln.modelData.t) / Math.max(1.5, ln.nextT - ln.modelData.t))) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12; radius: 6; color: "#ffffff"
                        opacity: 0.25 + 0.75 * Math.max(0, Math.min(1, f * 3 - index))
                        scale: 0.8 + 0.3 * Math.max(0, Math.min(1, f * 3 - index))
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                }
            }
            readonly property real nextT: ln.index + 1 < root.lines.length ? root.lines[ln.index + 1].t : ln.modelData.t + 5
            // click a line to jump the song to it (hand cursor, brightens on hover)
            HoverHandler { id: lnHover; cursorShape: root.synced ? Qt.PointingHandCursor : Qt.ArrowCursor }
            Rectangle { anchors.fill: parent; radius: 23; color: "#10ffffff"; opacity: root.synced && lnHover.hovered && !ln.cur ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 100 } } z: -1 }
            // a tapped line answers at once: it dips under the finger, flashes in the accent colour and eases back
            Rectangle { id: tapFlash; anchors.fill: parent; radius: 23; color: "#ffffff"; opacity: 0; z: -1 }
            NumberAnimation { id: tapAnim; target: tapFlash; property: "opacity"; from: 0.30; to: 0; duration: 520; easing.type: Easing.OutCubic }
            scale: lnTap.pressed ? 0.975 : 1
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            TapHandler { id: lnTap; enabled: root.synced; onTapped: { tapAnim.restart(); root.seekTo(ln.modelData.t) } }
        }
    }

    // nothing to show
    Column {
        visible: root.lines.length === 0
        anchors.centerIn: parent; spacing: 10
        BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: LyricsStore.state === "loading" ? "hourglass_top" : "lyrics"; size: 42; color: "#ffffff"; opacity: 0.5 }
        EText { anchors.horizontalCenter: parent.horizontalCenter; color: "#ffffff"; opacity: 0.6; font.pixelSize: 17
            text: LyricsStore.state === "loading" ? "Finding the words…" : (LyricsStore.state === "down" ? "The lyrics services are down, try again soon" : "No lyrics for this song") }
    }
    // small controls in the corner: text size, timing nudge, and where the words came from
    Row {
        visible: root.tools && root.lines.length > 0
        anchors { right: parent.right; top: parent.top; rightMargin: 4; topMargin: 2 }
        spacing: 6
        EText { anchors.verticalCenter: parent.verticalCenter; text: (LyricsStore.estimated ? "Timing estimated" : (root.synced ? "Synced" : "Not synced")) + (LyricsStore.source ? " · " + LyricsStore.source : ""); font.pixelSize: 11; color: "#ffffff"; opacity: 0.5; rightPadding: 6 }
        Repeater {
            model: [{ t: "A−", a: "s-" }, { t: "A+", a: "s+" }, { t: "−0.5s", a: "o-", sy: true }, { t: "+0.5s", a: "o+", sy: true }]
            delegate: Rectangle {
                id: cb
                required property var modelData
                visible: !modelData.sy || root.synced
                width: cbText.implicitWidth + 16; height: 26; radius: 17; color: cbHov.hovered ? "#44ffffff" : "#22ffffff"
                EText { id: cbText; anchors.centerIn: parent; text: cb.modelData.t; font.pixelSize: 11; color: "#ffffff" }
                HoverHandler { id: cbHov }
                TapHandler { onTapped: {
                    if (cb.modelData.a === "s-") root.size = Math.max(20, root.size - 3)
                    else if (cb.modelData.a === "s+") root.size = Math.min(52, root.size + 3)
                    else root.offset += cb.modelData.a === "o+" ? 0.5 : -0.5
                    root.follow()
                } }
            }
        }
    }
}
