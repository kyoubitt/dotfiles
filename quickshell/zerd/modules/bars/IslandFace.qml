import QtQuick
import Quickshell.Widgets
import qs
import qs.services

// Centre capsule: clock and date; when something plays, its title and cava
// bars join it. Click the clock for the calendar, the media part for controls.
BarPill {
    id: root

    readonly property var player: NowPlaying.player
    // a soft accent edge while music plays
    border.color: NowPlaying.isPlaying ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.45) : BarStyle.border
    Behavior on border.color { ColorAnimation { duration: 300 } }
    property int maxTextWidth: 220

    // Red dot while something records, shares the screen or uses the mic.
    Rectangle {
        visible: BarActivity.any
        width: 8; height: 8; radius: 4
        color: BarActivity.hot ? BarStyle.danger : BarStyle.subtext
        SequentialAnimation on opacity { running: BarActivity.hot; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 800 } NumberAnimation { to: 1; duration: 800 } }
        BarTip { text: BarActivity.chips.map(c => c.text + (c.sub ? " (" + c.sub + ")" : "")).join("  ·  ") }
    }
    // The time and the date are separate widgets: the clock and the calendar.
    Item {
        id: timePart
        implicitWidth: timeText.implicitWidth
        implicitHeight: timeText.implicitHeight
        BarText { id: timeText; text: DateTime.time; font.weight: Font.DemiBold }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPopup("clock")
        }
        BarTip { text: "Clock" }
    }
    Item {
        id: datePart
        visible: !root.vertical
        implicitWidth: dateText.implicitWidth
        implicitHeight: dateText.implicitHeight
        BarText { id: dateText; text: DateTime.shortDate; color: BarStyle.subtext }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPopup("calendar")
        }
        BarTip { text: "Calendar" }
    }
    Rectangle {
        visible: !root.vertical
        width: 1; height: 14
        color: BarStyle.border
    }
    // Nothing playing: say so, quietly; a click still opens the player.
    Item {
        id: idlePart
        visible: root.player === null && !root.vertical
        implicitWidth: idleRow.implicitWidth
        implicitHeight: idleRow.implicitHeight
        Row {
            id: idleRow
            spacing: 6
            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "music_off"; size: 16; color: BarStyle.subtext }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: "No media playing"; color: BarStyle.subtext }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPopup("media") }
    }
    Row {
        id: mediaPart
        visible: root.player !== null && !root.vertical
        spacing: 8
        // the cover of what plays
        Item {
            id: artPart
            visible: coverImg.status === Image.Ready
            width: 24; height: 24
            ClippingRectangle {
                anchors.fill: parent; radius: 8; color: BarStyle.plateHover
                Image { id: coverImg; anchors.fill: parent; source: NowPlaying.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(48, 48) }
            }
        }
        // Play / pause is its own target; the rest opens the player.
        Item {
            width: 24; height: 24
            BarIcon { anchors.centerIn: parent; name: NowPlaying.isPlaying ? "pause" : "play_arrow"; fill: 1; color: BarStyle.accent }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: NowPlaying.togglePlaying()
            }
            BarTip { text: NowPlaying.isPlaying ? "Pause" : "Play" }
        }
        Item {
            width: titleRow.implicitWidth; height: 24
            Row {
                id: titleRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarCava { visible: NowPlaying.isPlaying; count: 6 }
                BarMarquee {
                    text: root.player?.trackTitle ?? ""
                    width: 2 * Math.ceil(Math.min(measure.implicitWidth, root.maxTextWidth) / 2)
                    BarText { id: measure; visible: false; text: root.player?.trackTitle ?? "" }
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -2
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) NowPlaying.togglePlaying()
                    else root.openPopup("media")
                }
                onWheel: wheel => wheel.angleDelta.y > 0 ? NowPlaying.previous() : NowPlaying.next()
            }
        }
    }
}
