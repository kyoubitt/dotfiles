import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.bars

// The bar along the bottom, a glass card: the song with a heart on the left, the controls with the wavy seek line in
// the middle, and lyrics, devices, the right panel, volume and full screen on the right.
Item {
    id: root

    property int sleepMinutes: 0
    property int sleepSeconds: 0
    Timer {
        interval: 1000; repeat: true; running: root.sleepSeconds > 0
        onTriggered: {
            root.sleepSeconds--
            if (root.sleepSeconds <= 0) {
                root.sleepMinutes = 0
                if (Playback.isPlaying) Playback.toggle()
                MusicStore.tell("Sleep timer: paused")
            }
        }
    }
    height: 108
    signal openImmersive()

    readonly property var p: Playback.player
    property real pos: 0
    Connections { target: MusicStore; function onTrackKeyChanged() { root.pos = 0 } }
    Timer { interval: 400; repeat: true; running: root.visible && MusicStore.active; onTriggered: { if (root.p) { root.p.positionChanged(); root.pos = root.p.position } } }
    function clock(s: real): string { const n = Math.max(0, Math.round(s)); return Math.floor(n / 60) + ":" + (n % 60 < 10 ? "0" : "") + (n % 60) }

    component Tool: Rectangle {
        id: tl
        property string icon
        property bool on: false
        property int size: 22
        signal tapped()
        width: 40; height: 40; radius: 23
        color: th.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
        scale: tt.pressed ? 0.88 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.45 } }
        BarIcon { anchors.centerIn: parent; name: tl.icon; fill: tl.on ? 1 : 0; size: tl.size; color: tl.on ? MusicStore.accent : BarStyle.text }
        HoverHandler { id: th }
        TapHandler { id: tt; onTapped: tl.tapped() }
    }

    Rectangle {
        id: panel
        anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 8 }
        radius: 30
        color: Qt.rgba(0, 0, 0, 0.42)
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)

        // ---- the song
        Item {
            x: 20; width: MusicStore.narrow ? 230 : 400; height: parent.height
            ClippingRectangle {
                id: art
                SequentialAnimation { id: pop; NumberAnimation { target: art; property: "scale"; to: 0.82; duration: 70 } NumberAnimation { target: art; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack } }
                Connections { target: MusicStore; function onTrackKeyChanged() { pop.restart() } }
                anchors.verticalCenter: parent.verticalCenter; width: 68; height: 68; radius: 17; color: BarStyle.plate
                Image { anchors.fill: parent; source: CoverCache.src(root.p?.trackArtUrl ?? ""); sourceSize: Qt.size(150, 150); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; cache: true }
                TapHandler { onTapped: MusicStore.nowOpen = !MusicStore.nowOpen }
            }
            Column {
                x: 82; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 82 - 96; spacing: 3
                BarMarquee { width: parent.width; height: 22; text: root.p?.trackTitle ?? "Nothing playing"; weight: Font.DemiBold; pixelSize: 15 }
                BarMarquee { width: parent.width; height: 18; text: root.p?.trackArtist ?? ""; pixelSize: 13; weight: Font.Normal; color: BarStyle.subtext }
                EText { visible: (MusicStore.ctx?.name ?? "").length > 0; width: parent.width; elide: Text.ElideRight; text: "Playing from " + (MusicStore.ctx?.name ?? ""); font.pixelSize: 11; color: MusicStore.accent
                    TapHandler { onTapped: MusicStore.openContext() } }
            }
            Tool { anchors { right: parent.right; rightMargin: 44; verticalCenter: parent.verticalCenter } icon: "playlist_add"; onTapped: MusicStore.addCurrentToPlaylist() }
            Tool { anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "favorite"; on: MusicStore.liked; onTapped: MusicStore.toggleLike() }
        }

        // ---- controls and the seek line
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: MusicStore.narrow ? 20 + 230 + 14 : Math.round((parent.width - width) / 2)
            width: MusicStore.narrow ? Math.max(200, parent.width - 20 - 230 - 14 - 90 - 14) : Math.min(620, parent.width - 760); spacing: 4
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
                Tool { anchors.verticalCenter: parent.verticalCenter; icon: "shuffle"; on: MusicStore.shuffle; onTapped: MusicStore.toggleShuffle() }
                Tool { anchors.verticalCenter: parent.verticalCenter; icon: "skip_previous"; size: 28; onTapped: MusicStore.skip(-1) }
                Item {
                    width: 56; height: 56
                    scale: pt.pressed ? 0.92 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
                    Cookie {
                        anchors.fill: parent; color: MusicStore.accent; lobes: 9; amp: 0.07
                        spin: true; spinMs: MusicStore.skipping ? 900 : 9000
                    }
                    BarIcon { anchors.centerIn: parent; name: Playback.isPlaying ? "pause" : "play_arrow"; fill: 1; size: 30; color: MusicStore.onAccent }
                    TapHandler { id: pt; onTapped: Playback.toggle() }
                }
                Tool { anchors.verticalCenter: parent.verticalCenter; icon: "skip_next"; size: 28; onTapped: MusicStore.skip(1) }
                Tool { anchors.verticalCenter: parent.verticalCenter; icon: MusicStore.repeat === "track" ? "repeat_one" : "repeat"; on: MusicStore.repeat !== "off"; onTapped: MusicStore.cycleRepeat() }
            }
            Item {
                width: parent.width; height: 24
                EText { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 44; text: root.clock(root.pos); font.pixelSize: 12; color: BarStyle.subtext }
                WavySeek {
                    x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 104; tint: MusicStore.accent; rest: Qt.rgba(1, 1, 1, 0.2); playing: Playback.isPlaying
                    progress: (root.p && root.p.length > 0) ? Math.min(1, root.pos / root.p.length) : 0
                    onSeek: f => { if (root.p && root.p.length > 0) { root.p.position = root.p.length * f; root.pos = root.p.position } }
                }
                EText { anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 44; horizontalAlignment: Text.AlignRight; text: root.clock(root.p?.length ?? 0); font.pixelSize: 12; color: BarStyle.subtext }
            }
        }

        // ---- lyrics, devices, the right panel, volume, full screen
        Row {
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } spacing: 4
            // sleep timer: each tap steps off, 15, 30, 60 minutes; the music pauses when it runs out
            Tool {
                visible: !MusicStore.narrow
                icon: "bedtime"; on: root.sleepSeconds > 0
                onTapped: {
                    const next = { 0: 15, 15: 30, 30: 60, 60: 0 }[root.sleepMinutes] ?? 0
                    root.sleepMinutes = next; root.sleepSeconds = next * 60
                    MusicStore.tell(next > 0 ? "Sleep timer: " + next + " min" : "Sleep timer off")
                }
            }
            Tool { visible: !MusicStore.narrow; icon: "lyrics"; onTapped: root.openImmersive() }
            Tool { visible: !MusicStore.narrow; icon: "queue_music"; onTapped: { MusicStore.nowOpen = true } }
            Tool { visible: !MusicStore.narrow; icon: "devices"; onTapped: MusicStore.go("profile", null) }
            Item {
                visible: !MusicStore.narrow
                width: 150; height: 40
                BarIcon { x: 0; anchors.verticalCenter: parent.verticalCenter; name: MusicStore.volume === 0 ? "volume_off" : (MusicStore.volume < 50 ? "volume_down" : "volume_up"); size: 22; color: BarStyle.subtext
                    TapHandler { onTapped: MusicStore.setVolume(MusicStore.volume === 0 ? 50 : 0) } }
                BarSlider {
                    x: 32; width: 108; anchors.verticalCenter: parent.verticalCenter
                    trackHeight: 16
                    showValue: false
                    step: 0.05
                    tone: MusicStore.accent
                    value: MusicStore.volume / 100
                    onMoved: v => MusicStore.setVolume(Math.round(v * 100))
                }
            }
            Tool { visible: !MusicStore.narrow; icon: "dock_to_left"; on: MusicStore.nowOpen; onTapped: MusicStore.nowOpen = !MusicStore.nowOpen }
            Tool { icon: "open_in_full"; onTapped: root.openImmersive() }
        }
    }
}
