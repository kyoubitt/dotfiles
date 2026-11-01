import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.services

// Cover, track, seek bar, transport, shuffle/loop, volume and player switch.
Column {
    id: root

    property var p: NowPlaying.player
    readonly property real len: p?.length ?? 0
    readonly property real pos: p?.position ?? 0
    spacing: 14
    width: 320

    function fmt(t: real): string {
        const s = Math.max(0, Math.floor(t))
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    // Position is polled while the popup is open and a track is playing.
    Timer { interval: 1000; repeat: true; running: root.p?.isPlaying ?? false; onTriggered: root.p?.positionChanged() }

    // Nothing playing.
    Column {
        visible: root.p === null
        width: parent.width
        spacing: 8
        topPadding: 10; bottomPadding: 6
        BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "music_off"; size: 36; color: BarStyle.subtext }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: "No media playing"; font.weight: Font.DemiBold }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: "Start something and it shows up here"; font.pixelSize: 11; color: BarStyle.subtext }
    }
    ActivityChips { width: parent.width }

    Row {
        visible: root.p !== null
        spacing: 14
        ClippingRectangle {
            width: 96; height: 96; radius: 18
            color: BarStyle.plateHover
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
            BarIcon { anchors.centerIn: parent; name: "music_note"; size: 36; color: BarStyle.subtext; visible: (root.p?.trackArtUrl ?? "") === "" }
        }
        Column {
            width: root.width - 110
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            BarMarquee { width: parent.width; text: root.p?.trackTitle ?? "Nothing playing"; pixelSize: 16; weight: Font.DemiBold }
            BarMarquee { width: parent.width; text: root.p?.trackArtist ?? ""; color: BarStyle.subtext }
            BarMarquee { width: parent.width; text: root.p?.trackAlbum ?? ""; color: BarStyle.subtext; pixelSize: 12; visible: text.length > 0 }
            BarCava { visible: NowPlaying.isPlaying; count: 12 }
        }
    }

    Column {
        visible: root.p !== null
        width: parent.width
        spacing: 2
        Item {
            width: parent.width; height: 14
            Rectangle { y: 5; width: parent.width; height: 4; radius: 2; color: BarStyle.border }
            Rectangle { y: 5; width: root.len > 0 ? parent.width * Math.min(1, root.pos / root.len) : 0; height: 4; radius: 2; color: BarStyle.accent }
            MouseArea {
                anchors.fill: parent
                enabled: (root.p?.canSeek ?? false) && root.len > 0
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => { root.p.position = root.len * Math.max(0, Math.min(1, mouse.x / width)) }
            }
        }
        Item {
            width: parent.width; height: 16
            BarText { text: root.fmt(root.pos); font.pixelSize: 11; color: BarStyle.subtext }
            BarText { anchors.right: parent.right; text: root.fmt(root.len); font.pixelSize: 11; color: BarStyle.subtext }
        }
    }

    Row {
        visible: root.p !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16
        component Btn: Item {
            property string icon
            property bool lit: false
            property real glyph: 22
            signal tapped()
            width: 36; height: 36
            BarIcon { anchors.centerIn: parent; name: parent.icon; size: parent.glyph; fill: 1; color: parent.lit ? BarStyle.accent : BarStyle.text }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.tapped() }
        }
        Btn { icon: "shuffle"; glyph: 18; lit: MprisController.hasShuffle; visible: MprisController.shuffleSupported; onTapped: MprisController.setShuffle(!MprisController.hasShuffle) }
        Btn { icon: "skip_previous"; glyph: 26; onTapped: root.p?.previous() }
        Rectangle {
            width: 48; height: 48; radius: 24; color: BarStyle.accent
            BarIcon { anchors.centerIn: parent; name: NowPlaying.isPlaying ? "pause" : "play_arrow"; size: 28; fill: 1; color: BarStyle.onAccent }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NowPlaying.togglePlaying() }
        }
        Btn { icon: "skip_next"; glyph: 26; onTapped: root.p?.next() }
        Btn {
            visible: MprisController.loopSupported
            icon: MprisController.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            glyph: 18
            lit: MprisController.loopState !== MprisLoopState.None
            onTapped: MprisController.setLoopState(MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisController.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
        }
    }

    Row {
        visible: root.p !== null && MprisController.canChangeVolume
        spacing: 10
        BarIcon { name: "volume_up"; size: 16; color: BarStyle.subtext }
        Item {
            width: root.width - 26; height: 18
            Rectangle { y: 7; width: parent.width; height: 4; radius: 2; color: BarStyle.border }
            Rectangle { y: 7; width: parent.width * (root.p?.volume ?? 0); height: 4; radius: 2; color: BarStyle.accent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => { root.p.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                onPositionChanged: mouse => { if (pressed) root.p.volume = Math.max(0, Math.min(1, mouse.x / width)) }
            }
        }
    }

    Row {
        visible: MprisController.players.length > 1
        spacing: 6
        Repeater {
            model: MprisController.players
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData === root.p
                height: 24; width: nameText.implicitWidth + 20; radius: 12
                color: on ? BarStyle.accent : BarStyle.plateHover
                BarText { id: nameText; anchors.centerIn: parent; text: modelData.identity ?? "Player"; font.pixelSize: 11; color: parent.on ? BarStyle.onAccent : BarStyle.text }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.setActivePlayer(modelData) }
            }
        }
    }
}
