import QtQuick
import "../../../reusables"
import "../../../"

// The centre clock, our own: a small date tile (weekday over day number, in the accent) beside a large HH:mm.
// The layout idea is Caelestia's clock (date block in the tertiary colour, stacked digits); the code is ours.
// Fixed size, so nothing moves when the minute changes or the pointer passes over it.
Item {
    id: face
    property var widget: null

    property var now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: face.now = new Date() }

    readonly property color ink: ThemeBackend.text
    readonly property color soft: ThemeBackend.subtext0
    readonly property color accent: ThemeBackend.blue

    implicitWidth: row.implicitWidth
    implicitHeight: 32

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        // weekday over day number
        Rectangle {
            width: 30; height: 26
            anchors.verticalCenter: parent.verticalCenter
            radius: 9
            color: Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.22)
            Column {
                anchors.centerIn: parent
                spacing: -1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(face.now, "ddd").toUpperCase()
                    color: face.accent
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 8; font.weight: Font.Bold; font.letterSpacing: 0.5
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(face.now, "d")
                    color: face.ink
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
            }
        }

        // HH:mm, the colon a little lighter; digits are monospaced so the width never changes
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: Qt.formatTime(face.now, "HH")
                color: face.ink
                font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Bold
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }
            Text {
                text: ":"
                color: face.soft
                font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Bold
                renderType: Text.NativeRendering
                bottomPadding: 2
            }
            Text {
                text: Qt.formatTime(face.now, "mm")
                color: face.ink
                font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Bold
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }
        }
    }
}
