import QtQuick
import Quickshell.Widgets
import qs
import qs.services

// Centre block, two capsules: the clock and date (click the time for the clock, the date for the calendar) and, next
// to it, what plays: cover, title with cava, previous / play / next. Nothing playing leaves a quiet music button.
Item {
    id: root

    property int thickness: 34
    property int maxTextWidth: 220
    readonly property var player: NowPlaying.player

    implicitWidth: row.implicitWidth
    implicitHeight: thickness

    Row {
        id: row
        spacing: BarStyle.gap

        BarPill {
            id: clockPlate
            strip: true
            thickness: root.thickness
            // a soft accent edge while music plays
            border.color: NowPlaying.isPlaying ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.45) : BarStyle.border
            Behavior on border.color { ColorAnimation { duration: 300 } }

            // Red dot while something records, shares the screen or uses the mic.
            Item {
                visible: BarActivity.any
                width: 14; height: 14
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: BarActivity.hot ? BarStyle.danger : BarStyle.subtext
                    SequentialAnimation on opacity { running: BarActivity.hot; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 800 } NumberAnimation { to: 1; duration: 800 } }
                }
                BarTip { text: BarActivity.chips.map(c => c.text + (c.sub ? " (" + c.sub + ")" : "")).join("  ·  ") }
            }
            BarCell {
                tip: "Clock"
                padding: 9
                onTapped: clockPlate.openPopup("clock")
                BarText { text: DateTime.time; font.weight: Font.DemiBold }
            }
            BarCell {
                tip: "Calendar"
                padding: 9
                onTapped: clockPlate.openPopup("calendar")
                BarText { text: DateTime.shortDate; color: BarStyle.subtext }
            }
        }

        // Nothing playing.
        BarPill {
            id: idlePlate
            visible: root.player === null
            strip: true
            thickness: root.thickness
            BarCell {
                tip: "Nothing playing"
                onTapped: idlePlate.openPopup("media")
                BarIcon { name: "music_note"; color: BarStyle.subtext }
            }
        }

        BarPill {
            id: mediaPlate
            visible: root.player !== null
            strip: true
            thickness: root.thickness
            readonly property bool wide: root.maxTextWidth >= 60

            BarCell {
                tip: root.player?.trackAlbum ? root.player.trackAlbum : "Player"
                padding: 2
                onTapped: mediaPlate.openPopup("media")
                onMiddle: NowPlaying.togglePlaying()
                ClippingRectangle {
                    width: 24; height: 24; radius: 8
                    color: BarStyle.cardHigh
                    Image {
                        anchors.fill: parent
                        source: NowPlaying.activeTrack?.artUrl ?? ""
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    BarIcon { anchors.centerIn: parent; name: "music_note"; size: 16; color: BarStyle.subtext; visible: (NowPlaying.activeTrack?.artUrl ?? "") === "" }
                }
            }
            BarCell {
                visible: mediaPlate.wide
                tip: (root.player?.trackTitle ?? "") + ((root.player?.trackArtist ?? "") ? "  ·  " + root.player.trackArtist : "")
                padding: 6
                wheelEnabled: true
                onTapped: mediaPlate.openPopup("media")
                onMiddle: NowPlaying.togglePlaying()
                onWheel: event => event.angleDelta.y > 0 ? NowPlaying.previous() : NowPlaying.next()
                BarCava { visible: NowPlaying.isPlaying; anchors.verticalCenter: parent.verticalCenter; count: 6 }
                BarMarquee {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.player?.trackTitle ?? "") + ((root.player?.trackArtist ?? "") ? "  ·  " + root.player.trackArtist : "")
                    width: 2 * Math.ceil(Math.min(measure.implicitWidth, root.maxTextWidth) / 2)
                    BarText { id: measure; visible: false; text: parent.text }
                }
            }
            BarCell { tip: "Previous"; onTapped: NowPlaying.previous(); BarIcon { name: "skip_previous"; fill: 1; color: BarStyle.text } }
            BarCell {
                tip: NowPlaying.isPlaying ? "Pause" : "Play"
                fill: BarStyle.accent
                onTapped: NowPlaying.togglePlaying()
                BarIcon { name: NowPlaying.isPlaying ? "pause" : "play_arrow"; size: 20; fill: 1; color: BarStyle.onAccent }
            }
            BarCell { tip: "Next"; onTapped: NowPlaying.next(); BarIcon { name: "skip_next"; fill: 1; color: BarStyle.text } }
        }
    }
}
