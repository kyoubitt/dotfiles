import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.bars

// Right, like Spotify's "Now playing view": the cover, the song with a heart, the words being sung, what is next,
// and a card about the artist.
Rectangle {
    id: root
    width: 390
    radius: 26
    color: Qt.rgba(0, 0, 0, 0.30)
    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
    clip: true

    readonly property var p: Playback.player
    readonly property var item: MusicStore.player?.item ?? null
    property var artist: null
    property var queue: []
    property real pos: 0
    Timer { interval: 400; repeat: true; running: root.visible; onTriggered: { if (root.p) { root.p.positionChanged(); root.pos = root.p.position } } }

    // the artist card and the queue follow the song
    readonly property string artistId: item?.artists?.[0]?.id ?? ""
    onArtistIdChanged: { root.artist = null; if (artistId.length > 0) MusicApi.artist(artistId, j => root.artist = j) }
    readonly property string itemId: item?.id ?? ""
    onItemIdChanged: MusicApi.playerQueue(q => root.queue = (q?.queue ?? []).slice(0, 4))
    Component.onCompleted: { if (artistId.length > 0) MusicApi.artist(artistId, j => root.artist = j); MusicApi.playerQueue(q => root.queue = (q?.queue ?? []).slice(0, 4)) }

    // the line being sung and its neighbours
    readonly property int active: {
        const L = LyricsStore.lines
        if (!LyricsStore.synced || L.length === 0) return -1
        let lo = 0, hi = L.length - 1, at = -1
        while (lo <= hi) { const mid = (lo + hi) >> 1; if (L[mid].t <= root.pos + 0.2) { at = mid; lo = mid + 1 } else hi = mid - 1 }
        return at
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 24
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            x: 18; y: 18; width: parent.width - 36; spacing: 14

            Row {
                width: parent.width
                EText { width: parent.width - 40; elide: Text.ElideRight; text: (MusicStore.ctx?.name ?? "").length > 0 ? MusicStore.ctx.name : "Now playing"; font.weight: Font.Bold; font.pixelSize: 16 }
                Rectangle { width: 34; height: 34; radius: 17; color: xh.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    BarIcon { anchors.centerIn: parent; name: "close"; size: 20; color: BarStyle.subtext }
                    HoverHandler { id: xh }
                    TapHandler { onTapped: MusicStore.nowOpen = false } }
            }
            ClippingRectangle {
                width: parent.width; height: width; radius: 18; color: BarStyle.plate
                Image { anchors.fill: parent; source: CoverCache.src(root.p?.trackArtUrl ?? ""); sourceSize: Qt.size(640, 640); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: true }
                TapHandler { onTapped: MusicStore.immersive = true }
            }
            Row {
                width: parent.width
                Column {
                    width: parent.width - 44; spacing: 3
                    EText { width: parent.width; elide: Text.ElideRight; text: root.p?.trackTitle ?? "Nothing playing"; font.pixelSize: 24; font.weight: Font.Bold }
                    EText { width: parent.width; elide: Text.ElideRight; text: root.p?.trackArtist ?? ""; color: BarStyle.subtext
                        TapHandler { onTapped: { if (root.item?.artists?.[0]) MusicStore.go("artist", root.item.artists[0]) } } }
                }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 20; color: hh.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    BarIcon { anchors.centerIn: parent; name: "favorite"; fill: MusicStore.liked ? 1 : 0; size: 26; color: MusicStore.liked ? MusicStore.accent : BarStyle.text }
                    HoverHandler { id: hh }
                    TapHandler { onTapped: MusicStore.toggleLike() } }
            }

            // lyrics card
            Rectangle {
                width: parent.width; height: lyr.implicitHeight + 70; radius: 20
                color: Qt.rgba(MusicStore.accent.r, MusicStore.accent.g, MusicStore.accent.b, 0.22)
                Row { x: 16; y: 14; spacing: 10
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "lyrics"; size: 20; color: BarStyle.text }
                    EText { anchors.verticalCenter: parent.verticalCenter; text: "Lyrics"; font.weight: Font.Bold } }
                Rectangle { anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 } width: 34; height: 34; radius: 17; color: lh.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    BarIcon { anchors.centerIn: parent; name: "open_in_full"; size: 18; color: BarStyle.text }
                    HoverHandler { id: lh }
                    TapHandler { onTapped: MusicStore.immersive = true } }
                Column {
                    id: lyr
                    x: 8; y: 52; width: parent.width - 16; spacing: 2
                    EText { visible: LyricsStore.lines.length === 0; width: parent.width; wrapMode: Text.Wrap; color: BarStyle.subtext
                        text: LyricsStore.state === "loading" ? "Finding the words…" : "No lyrics for this song" }
                    Repeater {
                        model: {
                            const L = LyricsStore.lines
                            if (L.length === 0) return []
                            const start = LyricsStore.synced ? Math.max(0, root.active - 1) : 0
                            return L.slice(start, start + (LyricsStore.synced ? 4 : 5)).map((l, i) => ({ s: l.s, t: l.t, cur: LyricsStore.synced && start + i === root.active }))
                        }
                        // each line is a button: the whole row (not just the letters) hovers, presses and jumps the song to it
                        delegate: Item {
                            id: ln
                            required property var modelData
                            width: lyr.width; height: lt.implicitHeight + 12
                            scale: lnt.pressed ? 0.98 : 1
                            Behavior on scale { SpringAnimation { spring: 8; damping: 0.5 } }
                            Rectangle {
                                anchors.fill: parent; radius: 12
                                color: Qt.rgba(1, 1, 1, lnt.pressed ? 0.16 : 0.09)
                                opacity: lnh.hovered && !ln.modelData.cur ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 90 } }
                            }
                            EText {
                                id: lt
                                x: 8; y: 6; width: parent.width - 16; wrapMode: Text.Wrap; text: ln.modelData.s.length > 0 ? ln.modelData.s : "♪"
                                font.pixelSize: ln.modelData.cur ? 20 : 17; font.weight: Font.Bold
                                opacity: LyricsStore.synced ? (ln.modelData.cur ? 1 : (lnh.hovered ? 0.85 : 0.5)) : 0.9
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            HoverHandler { id: lnh; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: lnt
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: { if (LyricsStore.synced && root.p) root.p.position = ln.modelData.t; else MusicStore.immersive = true }
                            }
                        }
                    }
                }
            }

            // what is next
            Column {
                width: parent.width; spacing: 6; visible: root.queue.length > 0
                Row { width: parent.width
                    EText { width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter; text: "Next in queue"; font.weight: Font.Bold; font.pixelSize: 16 }
                    Rectangle { width: oq.implicitWidth + 20; height: 26; radius: 13; color: oqh.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                        EText { id: oq; anchors.centerIn: parent; text: "Open queue"; font.pixelSize: 12; color: BarStyle.subtext }
                        HoverHandler { id: oqh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: MusicStore.immersive = true } } }
                Repeater {
                    model: root.queue.slice(0, 3)
                    delegate: Item {
                        id: qi
                        required property var modelData
                        width: parent.width; height: 56
                        Rectangle { anchors.fill: parent; radius: 14; color: qh.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
                        ClippingRectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42; radius: 8; color: BarStyle.plate
                            Image { anchors.fill: parent; source: CoverCache.src(MusicStore.artOf(qi.modelData, false)); sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true } }
                        Column { x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70
                            EText { width: parent.width; elide: Text.ElideRight; text: qi.modelData.name; font.weight: Font.DemiBold }
                            EText { width: parent.width; elide: Text.ElideRight; text: MusicStore.artistsOf(qi.modelData); font.pixelSize: 12; color: BarStyle.subtext } }
                        HoverHandler { id: qh }
                    }
                }
            }

            // about the artist
            ClippingRectangle {
                visible: root.artist !== null
                width: parent.width; height: 240; radius: 20; color: BarStyle.plate
                Image { anchors.fill: parent; source: CoverCache.src(MusicStore.artOf(root.artist, true)); sourceSize: Qt.size(640, 640); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
                Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.3; color: "#00000000" } GradientStop { position: 1; color: "#dd000000" } } }
                EText { x: 16; y: 14; text: "About the artist"; font.weight: Font.Bold; color: "#ffffff" }
                Column { x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16; width: parent.width - 32; spacing: 3
                    EText { width: parent.width; elide: Text.ElideRight; text: root.artist?.name ?? ""; font.pixelSize: 20; font.weight: Font.Bold; color: "#ffffff" }
                    EText { text: (root.artist?.followers?.total ?? 0) > 0 ? Number(root.artist.followers.total).toLocaleString(Qt.locale(), "f", 0) + " followers" : ""; color: "#ffffff"; opacity: 0.8; font.pixelSize: 12 }
                    EText { width: parent.width; elide: Text.ElideRight; text: (root.artist?.genres ?? []).slice(0, 3).join("  ·  "); color: "#ffffff"; opacity: 0.7; font.pixelSize: 12 } }
                TapHandler { onTapped: if (root.artist) MusicStore.go("artist", root.artist) }
            }
        }
    }
}
