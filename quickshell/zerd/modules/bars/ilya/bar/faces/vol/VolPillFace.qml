import QtQuick
import "../../../reusables"
import "../../../"
import "../../"

// Volume on the bar: speaker glyph, the level, and a thin level bar under it. The wheel changes the volume in steps of 2,
// a middle click mutes, a click opens the volume popup.
BarFaceBase {
    id: root
    readonly property var sink: Audio.defaultSink
    readonly property real vol: isPreview ? 65 : (sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0)
    readonly property bool muted: isPreview ? false : (sink && sink.audio ? sink.audio.muted : false)
    readonly property string glyph: muted || vol === 0 ? "volume_off" : (vol < 35 ? "volume_mute" : (vol < 70 ? "volume_down" : "volume_up"))

    property bool isFaceVisible: true
    implicitWidth: 72
    implicitHeight: parent ? parent.height : 0

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: 66; height: 30; radius: 15
        color: ma.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
        Behavior on color { ColorAnimation { duration: 140 } }
        clip: true

        // the level, drawn as a soft fill from the left
        Rectangle {
            height: parent.height
            width: parent.width * Math.max(0, Math.min(1, root.vol / 100))
            color: Qt.alpha(ThemeBackend.blue, root.muted ? 0.08 : 0.22)
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
        Row {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph
                font.family: "Material Symbols Rounded"
                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                font.pixelSize: 17
                color: root.muted ? ThemeBackend.subtext0 : ThemeBackend.blue
                renderType: Text.NativeRendering
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                text: root.muted ? "mute" : root.vol
                font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                color: root.muted ? ThemeBackend.subtext0 : ThemeBackend.text
                renderType: Text.NativeRendering
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) { if (root.sink) Audio.toggleMute(root.sink) }
            else Popups.toggle("volume", root)
        }
        onWheel: wheel => {
            if (!root.sink) return
            const step = wheel.angleDelta.y > 0 ? 2 : -2
            Audio.setVolume(root.sink, Math.max(0, Math.min(100, root.vol + step)))
            wheel.accepted = true
        }
    }
}
