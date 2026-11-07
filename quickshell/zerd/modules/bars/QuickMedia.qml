// Player card after end-4/dots-hyprland's PlayerControl (GPL-3.0): the cover, a seek bar between previous and next, a play button that squares up while it plays.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services

// The player on a blurred copy of its own cover.
ClippingRectangle {
    id: root

    readonly property var p: NowPlaying.player
    readonly property bool has: p !== null && p !== undefined
    readonly property real len: p?.length ?? 0
    readonly property real pos: p?.position ?? 0
    readonly property bool playing: NowPlaying.isPlaying

    function fmt(t: real): string {
        const s = Math.max(0, Math.floor(t))
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    implicitHeight: has ? 152 : 84
    radius: BarStyle.radiusMedium
    color: BarStyle.card
    border.width: 1
    border.color: BarStyle.edge
    Behavior on implicitHeight { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutCubic } }

    // position is polled while the card is on screen and a track plays
    Timer { interval: 1000; repeat: true; running: root.playing && root.visible; onTriggered: root.p?.positionChanged() }

    Image {
        id: art
        anchors.fill: parent
        source: root.p?.trackArtUrl ?? ""
        sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.35
        opacity: art.status === Image.Ready ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    // a veil so the text reads whatever the cover looks like
    Rectangle { anchors.fill: parent; color: Qt.rgba(BarStyle.card.r, BarStyle.card.g, BarStyle.card.b, art.status === Image.Ready ? 0.4 : 0) }

    // nothing playing
    Column {
        visible: !root.has
        anchors.centerIn: parent
        spacing: 4
        BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "music_off"; size: 26; color: BarStyle.subtext }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: "No media playing"; font.pixelSize: 12; color: BarStyle.subtext }
    }

    Item {
        visible: root.has
        anchors.fill: parent

        // cover
        ClippingRectangle {
            id: cover
            x: 14; y: 14
            width: 84; height: 84; radius: 12
            color: BarStyle.cardHigh
            Image {
                anchors.fill: parent
                source: root.p?.trackArtUrl ?? ""
                sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            BarIcon { anchors.centerIn: parent; name: "music_note"; size: 32; color: BarStyle.subtext; visible: (root.p?.trackArtUrl ?? "") === "" }
        }

        // title, artist and the time
        Item {
            x: cover.x + cover.width + 14; y: cover.y
            width: parent.width - x - 14; height: cover.height
            BarMarquee { width: parent.width; text: root.p?.trackTitle ?? "Nothing playing"; pixelSize: 15; weight: Font.DemiBold }
            BarMarquee { y: 22; width: parent.width - 54; text: root.p?.trackArtist ?? ""; color: BarStyle.subtext; pixelSize: 12 }
            BarText { y: parent.height - height; text: root.fmt(root.pos) + " / " + root.fmt(root.len); font.pixelSize: 11; color: BarStyle.subtext }
            // play: a circle while paused, a rounded square in the accent while it plays
            BarButton {
                id: playBtn
                anchors.right: parent.right
                y: parent.height - height - 18
                width: 44; height: 44
                tone: root.playing ? "filled" : "tonal"
                radius: root.playing ? BarStyle.radiusMedium : height / 2
                Behavior on radius { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
                BarIcon { anchors.centerIn: parent; name: root.playing ? "pause" : "play_arrow"; size: 26; fill: 1; color: playBtn.ink }
                onTapped: NowPlaying.togglePlaying()
            }
        }

        // previous, seek bar, next
        Row {
            x: 10; y: cover.y + cover.height + 10
            width: parent.width - 20; height: 32
            spacing: 4
            BarButton {
                id: prevBtn
                tone: "plain"; width: 32; height: 32; radius: 16
                BarIcon { anchors.centerIn: parent; name: "skip_previous"; size: 22; fill: 1; color: prevBtn.ink }
                onTapped: root.p?.previous()
            }
            Item {
                id: seek
                width: parent.width - 2 * 32 - 2 * parent.spacing; height: parent.height
                readonly property real frac: root.len > 0 ? Math.max(0, Math.min(1, root.pos / root.len)) : 0
                Rectangle { y: Math.round((parent.height - 8) / 2); width: parent.width; height: 8; radius: 4; color: Qt.tint(BarStyle.cardHigh, Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.2)) }
                Rectangle { y: Math.round((parent.height - 8) / 2); width: Math.max(8, Math.round(parent.width * seek.frac)); height: 8; radius: 4; color: BarStyle.accent; visible: root.len > 0 }
                MouseArea {
                    anchors.fill: parent
                    enabled: (root.p?.canSeek ?? false) && root.len > 0
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => { root.p.position = root.len * Math.max(0, Math.min(1, mouse.x / width)) }
                    onPositionChanged: mouse => { if (pressed) root.p.position = root.len * Math.max(0, Math.min(1, mouse.x / width)) }
                }
            }
            BarButton {
                id: nextBtn
                tone: "plain"; width: 32; height: 32; radius: 16
                BarIcon { anchors.centerIn: parent; name: "skip_next"; size: 22; fill: 1; color: nextBtn.ink }
                onTapped: root.p?.next()
            }
        }
    }
}
