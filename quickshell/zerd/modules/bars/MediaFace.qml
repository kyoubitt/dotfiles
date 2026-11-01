import QtQuick
import qs.services

// Track title with play/pause on click, next on middle click.
BarPill {
    id: root

    readonly property var player: NowPlaying.player
    property int maxTextWidth: 200
    visible: player !== null
    interactive: true
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) root.player?.next()
        else NowPlaying.togglePlaying()
    }

    BarIcon {
        name: NowPlaying.isPlaying ? "pause" : "play_arrow"
        fill: 1
        color: BarStyle.accent
    }
    BarCava { visible: root.visible && NowPlaying.isPlaying; count: 8 }
    BarText {
        visible: !root.vertical
        text: (root.player?.trackTitle ?? "") + (root.player?.trackArtists ? "  ·  " + root.player.trackArtists : "")
        elide: Text.ElideRight
        width: 2 * Math.ceil(Math.min(implicitWidth, root.maxTextWidth) / 2)
    }
}
