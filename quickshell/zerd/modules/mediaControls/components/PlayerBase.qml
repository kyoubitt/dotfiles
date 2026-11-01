import QtQuick
import Quickshell
import qs.services

// Slim stand-in for iNiR's PlayerBase: the state the iRiS now-playing card
// reads from the active MPRIS player, plus transport actions.
QtObject {
    id: root

    required property var player
    property bool positionUpdatesActive: true

    readonly property bool effectiveIsPlaying: player?.isPlaying ?? false
    readonly property string effectiveTitle: NowPlaying.activeTrack?.title ?? ""
    readonly property string effectiveArtist: NowPlaying.activeTrack?.artist ?? ""
    readonly property string effectiveArtUrl: NowPlaying.activeTrack?.artUrl ?? ""
    readonly property string displayedArtFilePath: effectiveArtUrl
    readonly property real effectivePosition: player?.position ?? 0
    readonly property real effectiveLength: player?.length ?? 0
    readonly property bool effectiveCanSeek: player?.canSeek ?? false
    readonly property bool effectiveCanGoPrevious: NowPlaying.canGoPrevious
    readonly property bool effectiveCanGoNext: NowPlaying.canGoNext

    property var colorQuantizer: ColorQuantizer {
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    // MPRIS position doesn't update on its own while playing.
    property var _tick: Timer {
        interval: 1000
        repeat: true
        running: root.positionUpdatesActive && root.effectiveIsPlaying
        onTriggered: if (root.player) root.player.positionChanged()
    }

    function previous(): void { NowPlaying.previous() }
    function next(): void { NowPlaying.next() }
    function togglePlaying(): void { NowPlaying.togglePlaying() }
}
