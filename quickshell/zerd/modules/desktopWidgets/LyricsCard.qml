import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common
import qs.modules.bars
import qs.modules.iris.widgets
import "../bars/ilya"
import "../bars/ilya/reusables/media"

// The words of the song that is playing, drawn by ilyamiro's lyrics view: the sung line big and bright, the lines
// around it fading with distance, gliding up as the song goes, with a soft fade at the top and bottom edge.
// A bigger card shows more lines at the same text size.
IrisWidgetFace {
    id: root

    readonly property bool playing: NowPlaying.isPlaying
    readonly property string title: NowPlaying.player?.trackTitle ?? ""

    // his view reads the shared `Lyrics` singleton, which only fetches while somebody is subscribed
    Component.onCompleted: Lyrics.subscribe()
    Component.onDestruction: Lyrics.unsubscribe()

    Item {
        id: stage
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fade
            maskThresholdMin: 0.0
            maskSpreadAtMin: 0.0
        }

        LyricsView {
            anchors.fill: parent
            alignment: "left"
            sideMargin: 4
            baseActiveFont: 24
            lineHeight: 34
            lineSpacing: 8
            activeLineColor: "#ffffff"
            inactiveLineColor: Qt.rgba(1, 1, 1, 0.9)
            inactiveOpacity: 0.42
            fontFamily: Appearance.font.family.expressive
        }
    }
    // the edge fade: opaque in the middle, clear at the top and bottom
    Rectangle {
        id: fade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.18; color: "#000000" }
            GradientStop { position: 0.82; color: "#000000" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    BarText {
        anchors.centerIn: parent
        visible: !Lyrics.hasLyrics
        text: root.title.length === 0 ? "Nothing playing" : (Lyrics.loading ? "Finding the words…" : "No lyrics for this song")
        color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: 14
    }
}
