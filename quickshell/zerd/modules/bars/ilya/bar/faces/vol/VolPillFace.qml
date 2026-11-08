import QtQuick
import QtQuick.Shapes
import "../../../reusables"
import "../../../"
import "../../"

// Volume on the bar, in the same language as the CPU and RAM rings: a ring that fills with the level around a speaker glyph,
// the number beside it. The wheel changes the volume in steps of 2, a middle or right click mutes, a click opens the popup.
BarFaceBase {
    id: root
    readonly property var sink: Audio.defaultSink
    readonly property real vol: isPreview ? 65 : (sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0)
    readonly property bool muted: isPreview ? false : (sink && sink.audio ? sink.audio.muted : false)
    readonly property string glyph: muted || vol === 0 ? "volume_off" : (vol < 50 ? "volume_down" : "volume_up")

    property bool isFaceVisible: true
    implicitWidth: 76
    implicitHeight: parent ? parent.height : 0

    Item {
        id: box
        anchors.centerIn: parent
        width: 66; height: 28

        Item {
            id: ringBox
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(ThemeBackend.text, 0.16); strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: root.muted ? ThemeBackend.subtext0 : ThemeBackend.blue; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: -90
                        sweepAngle: root.muted ? 0 : 360 * Math.max(0.02, Math.min(1, root.vol / 100))
                        Behavior on sweepAngle { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.glyph
                font.family: "Material Symbols Rounded"
                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                font.pixelSize: 12
                color: root.muted ? ThemeBackend.subtext0 : ThemeBackend.text
                renderType: Text.NativeRendering
            }
        }
        Text {
            x: ringBox.width + 5
            width: 34
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "mute" : root.vol
            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
            color: root.muted ? ThemeBackend.subtext0 : ThemeBackend.text
            renderType: Text.NativeRendering
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
