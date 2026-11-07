pragma Singleton
import QtQuick
import qs.services as Svc

QtObject {
    id: root

    readonly property var activePlayer: Svc.MprisController.activePlayer
    readonly property bool isPlaying: Svc.MprisController.isPlaying
    readonly property string artUrl: activePlayer?.trackArtUrl ?? ""
    property real livePosition: activePlayer ? activePlayer.position : 0

    property Timer tick: Timer {
        interval: 1000
        repeat: true
        running: root.activePlayer !== null && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }
    onActivePlayerChanged: if (activePlayer) livePosition = activePlayer.position
}
