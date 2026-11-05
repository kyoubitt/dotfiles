import QtQuick
import Quickshell.Widgets
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
import qs.services.deferred
import qs.modules.bars

// The full-window player: the cover as a slow liquid backdrop, big art, synced lyrics, the queue, a spectrum and
// the loop and trash tools.
Item {
    id: root
    anchors.fill: parent
    signal closed()
    // two equal halves with room at the sides: the player is centred in the left one, the words fill the right one
    readonly property real pad: Math.max(60, width * 0.05)
    readonly property real half: (width - 2 * pad) / 2

    readonly property var p: Playback.player
    readonly property string artUrl: p?.trackArtUrl ?? ""
    readonly property string title: p?.trackTitle ?? ""
    readonly property string artist: p?.trackArtist ?? ""
    property real pos: 0
    Connections { target: MusicStore; function onTrackKeyChanged() { root.pos = 0 } }
    property bool showQueue: false
    // a swell that runs on every new lyric line: it nudges the colour blobs
    property real pulse: 0
    property real clock: 0
    Timer { interval: 66; repeat: true; running: Playback.isPlaying && root.visible; onTriggered: root.clock += 0.066 }
    Connections { target: right; function onActiveChanged() { if (root.visible) pulseAnim.restart() } }
    NumberAnimation { id: pulseAnim; target: root; property: "pulse"; from: 1; to: 0; duration: 700; easing.type: Easing.OutCubic }
    property var queue: []

    function fmt(t: real): string { const m = Math.floor(t / 60), s = Math.floor(t % 60); return m + ":" + (s < 10 ? "0" : "") + s }
    function fetch(): void { LyricsStore.request(root.title, root.artist, root.p?.length ?? 0) }
    onTitleChanged: fetch()
    Component.onCompleted: { fetch(); MusicApi.playerQueue(q => root.queue = (q?.queue ?? []).slice(0, 12)) }
    Timer { interval: 120; repeat: true; running: true; onTriggered: { if (root.p) { root.p.positionChanged(); root.pos = root.p.position } } }

    // ---- the liquid backdrop
    Rectangle { anchors.fill: parent; color: "#0c0c10" }
    Item {
        anchors.fill: parent; clip: true
        // blurred once into a small cached texture, then only that texture is scaled and turned (cheap, no per-frame blur)
        Item {
            id: liquid
            anchors.centerIn: parent
            width: 256; height: 256
            // driven by the shared slow clock (15 fps) instead of free-running animations, so the window is not redrawn at 60 fps
            readonly property real grow: 1.0 + 0.1 * (1 - Math.cos(root.clock * Math.PI / 10))
            scale: Math.max(root.width, root.height) * 1.5 / 256 * grow
            rotation: 8 * Math.sin(root.clock * Math.PI / 15)
            Item {
                anchors.fill: parent; layer.enabled: true; layer.smooth: true
                Image { id: bg; anchors.fill: parent; source: CoverCache.src(root.artUrl); sourceSize: Qt.size(128, 128); fillMode: Image.PreserveAspectCrop; visible: false; cache: true }
                MultiEffect { anchors.fill: parent; source: bg; blurEnabled: true; blur: 1.0; blurMax: 32; saturation: 0.5; brightness: -0.12; autoPaddingEnabled: false }
            }
        }
        // soft colour that drifts slowly behind everything, painted as radial gradients (no blur pass, so it costs almost nothing)
        component Blob: Item {
            id: bl
            property color tint: "white"
            property real a: 0.45
            property real sz: 520
            property real pu: 0
            property real pv: 0
            // one slow shared clock (15 fps is plenty for colour this soft)
            readonly property real u: 0.5 - 0.5 * Math.cos(root.clock * Math.PI / (bl.ms / 1000) + bl.pu)
            readonly property real v: 0.5 - 0.5 * Math.cos(root.clock * Math.PI / (bl.ms * 1.3 / 1000) + bl.pv)
            property int ms: 30000
            readonly property real grow: 1 + 0.05 * Math.sin(u * Math.PI) + 0.07 * root.pulse
            width: sz; height: sz; scale: grow
            layer.enabled: true; layer.smooth: true      // painted once into a texture, then only moved
            x: -sz * 0.25 + u * (root.width - sz * 0.5)
            y: -sz * 0.25 + v * (root.height - sz * 0.5)
            Behavior on tint { ColorAnimation { duration: 600 } }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: bl.sz / 2; centerY: bl.sz / 2; centerRadius: bl.sz / 2; focalX: bl.sz / 2; focalY: bl.sz / 2
                        GradientStop { position: 0; color: Qt.rgba(bl.tint.r, bl.tint.g, bl.tint.b, bl.a) }
                        GradientStop { position: 1; color: Qt.rgba(bl.tint.r, bl.tint.g, bl.tint.b, 0) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: bl.sz; y: 0 }
                    PathLine { x: bl.sz; y: bl.sz }
                    PathLine { x: 0; y: bl.sz }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
        Blob { tint: MusicStore.accent; a: 0.5; pu: 0.6; pv: 2.5; ms: 27000 }
        Blob { tint: Qt.hsla((MusicStore.accent.hslHue + 0.1) % 1, Math.max(0.5, MusicStore.accent.hslSaturation), 0.5, 1); a: 0.4; pu: 2.8; pv: 1.0; ms: 33000; sz: 460 }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.34 + 0.4 * MusicStore.coverLum }
    }

    // close
    Rectangle {
        x: 22; y: 20; width: 44; height: 44; radius: 22; color: cHov.hovered ? "#44ffffff" : "#26ffffff"
        BarIcon { anchors.centerIn: parent; name: "keyboard_arrow_down"; size: 26; color: "#ffffff" }
        HoverHandler { id: cHov }
        TapHandler { onTapped: root.closed() }
    }
    // queue toggle
    Rectangle {
        anchors { right: parent.right; rightMargin: 24 } y: 20; width: 44; height: 44; radius: 22; color: root.showQueue ? "#ffffff" : (qHov.hovered ? "#44ffffff" : "#26ffffff")
        BarIcon { anchors.centerIn: parent; name: "queue_music"; size: 22; color: root.showQueue ? "#111111" : "#ffffff" }
        HoverHandler { id: qHov }
        TapHandler { onTapped: { root.showQueue = !root.showQueue; if (root.showQueue) MusicApi.playerQueue(q => root.queue = (q?.queue ?? []).slice(0, 12)) } }
    }

    // ---- art, names, seek, tools
    Item {
        x: root.pad + (root.half - width) / 2; width: Math.min(420, root.half - 80); height: parent.height
        ClippingRectangle {
            id: big
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -50
            width: parent.width; height: width; radius: 36; color: BarStyle.plate
            scale: Playback.isPlaying ? 1 : 0.92
            Behavior on scale { SpringAnimation { spring: 3; damping: 0.4 } }
            opacity: 1
            SequentialAnimation { id: bigPop; NumberAnimation { target: big; property: "opacity"; to: 0.3; duration: 90 } NumberAnimation { target: big; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic } }
            Connections { target: MusicStore; function onTrackKeyChanged() { bigPop.restart() } }
            Image { anchors.fill: parent; source: CoverCache.src(root.artUrl); sourceSize: Qt.size(720, 720); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: true }
        }
        // a glow behind the cover that breathes with the bass
        Rectangle {
            z: -1; anchors.centerIn: big; width: big.width * 0.9; height: width; radius: 40; color: MusicStore.accent
            readonly property real bass: Math.min(1, ((CavaService.points[0] ?? 0) + (CavaService.points[1] ?? 0)) / 2 / CavaService.normalizationCeiling)
            opacity: Playback.isPlaying ? 0.28 + 0.4 * bass : 0.18
            Behavior on opacity { NumberAnimation { duration: 90 } }
            scale: 1.02 + 0.07 * bass
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48 }
        }
        Column {
            anchors.top: big.bottom; anchors.topMargin: 26; width: parent.width; spacing: 4
            EText { width: parent.width; elide: Text.ElideRight; text: root.title || "Nothing playing"; font.pixelSize: 26; font.weight: Font.Bold; color: "#ffffff" }
            EText { width: parent.width; elide: Text.ElideRight; text: root.artist; font.pixelSize: 15; color: "#ffffff"; opacity: 0.75 }
            WavySeek {
                width: parent.width; playing: Playback.isPlaying; tint: "#ffffff"
                progress: (root.p && root.p.length > 0) ? Math.min(1, root.pos / root.p.length) : 0
                onSeek: f => { if (root.p && root.p.length > 0) root.p.position = root.p.length * f }
            }
            Item { width: parent.width; height: 16
                EText { text: root.fmt(root.pos); font.pixelSize: 12; color: "#ffffff"; opacity: 0.6 }
                EText { anchors.right: parent.right; text: root.fmt(root.p?.length ?? 0); font.pixelSize: 12; color: "#ffffff"; opacity: 0.6 } }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; topPadding: 12
                component Btn: Rectangle {
                    id: bt
                    property string icon
                    property bool on: false
                    signal tapped()
                    width: 46; height: 46; radius: 23; anchors.verticalCenter: parent.verticalCenter
                    color: bh.hovered ? "#33ffffff" : "transparent"
                    scale: bp.pressed ? 0.9 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
                    BarIcon { anchors.centerIn: parent; name: bt.icon; fill: bt.on ? 1 : 0; size: 26; color: bt.on ? MusicStore.accent : "#ffffff" }
                    HoverHandler { id: bh }
                    TapHandler { id: bp; onTapped: bt.tapped() }
                }
                Btn { icon: "shuffle"; on: MusicStore.shuffle; onTapped: MusicStore.toggleShuffle() }
                Btn { icon: "skip_previous"; onTapped: MusicStore.skip(-1) }
                Item {
                    width: 64; height: 64; anchors.verticalCenter: parent.verticalCenter
                    scale: pp.pressed ? 0.92 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                    Cookie { anchors.fill: parent; color: "#ffffff"; lobes: 9; amp: 0.07; spin: true; spinMs: 8000 }
                    BarIcon { anchors.centerIn: parent; name: Playback.isPlaying ? "pause" : "play_arrow"; fill: 1; size: 34; color: "#111111" }
                    TapHandler { id: pp; onTapped: Playback.toggle() }
                }
                Btn { icon: "skip_next"; onTapped: MusicStore.skip(1) }
                Btn { icon: MusicStore.repeat === "track" ? "repeat_one" : "repeat"; on: MusicStore.repeat !== "off"; onTapped: MusicStore.cycleRepeat() }
                Btn { icon: "favorite"; on: MusicStore.liked; onTapped: MusicStore.toggleLike() }
            }
        }
    }

    // ---- lyrics, or the queue
    LyricsView {
        id: right
        x: root.pad + root.half + 30; width: root.half - 30; y: 110; height: parent.height - 300
        visible: !root.showQueue
        position: root.pos
        onSeekTo: t => { if (root.p) root.p.position = t }
    }
    Item {
        x: right.x; y: 80; width: right.width; height: right.height; visible: root.showQueue
        EText { text: "Up next"; font.pixelSize: 22; font.weight: Font.Bold; color: "#ffffff" }
        ListView {
            y: 44; width: parent.width; height: parent.height - 44; clip: true; boundsBehavior: Flickable.StopAtBounds
            model: root.queue
            delegate: Item {
                id: qi
                required property var modelData
                width: ListView.view.width; height: 58
                Rectangle { anchors.fill: parent; radius: 16; color: qiHov.hovered ? "#26ffffff" : "transparent" }
                ClippingRectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42; radius: 10; color: "#33ffffff"
                    Image { anchors.fill: parent; source: CoverCache.src(MusicStore.artOf(qi.modelData, false)); sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true } }
                Column { x: 62; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 74
                    EText { width: parent.width; elide: Text.ElideRight; text: qi.modelData.name; color: "#ffffff"; font.weight: Font.Medium }
                    EText { width: parent.width; elide: Text.ElideRight; text: MusicStore.artistsOf(qi.modelData); color: "#ffffff"; opacity: 0.65; font.pixelSize: 12 } }
                HoverHandler { id: qiHov }
            }
        }
    }

    // ---- spectrum
    Spectrum {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: root.pad; rightMargin: root.pad; bottomMargin: 6 }
        height: 140
        pulseKey: right.synced ? right.active : -1
    }
}
