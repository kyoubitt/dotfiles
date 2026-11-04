import QtQuick
import Quickshell.Widgets

// The charge as a liquid bar: the fill ends in a gentle wave that moves while the battery charges and rests otherwise.
ClippingRectangle {
    id: root

    property real level: 0
    property color tone: BarStyle.accent
    property bool charging: false
    property real phase: 0

    height: 48
    radius: BarStyle.radiusMedium
    color: BarStyle.cardHigh

    Timer {
        interval: 40; repeat: true; running: root.charging && root.visible
        onTriggered: { root.phase += 0.22; wave.requestPaint() }
    }
    Canvas {
        id: wave
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: root; function onLevelChanged() { wave.requestPaint() } function onToneChanged() { wave.requestPaint() } }
        onPaint: {
            const c = getContext("2d")
            c.reset()
            const edge = Math.max(0, Math.min(1, root.level)) * width
            const amp = root.charging ? 4 : 1.5
            c.fillStyle = Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.85)
            c.beginPath()
            c.moveTo(0, 0)
            c.lineTo(edge + amp, 0)
            for (let y = 0; y <= height; y += 2) c.lineTo(edge + amp * Math.sin(y / 7 + root.phase), y)
            c.lineTo(0, height)
            c.closePath()
            c.fill()
        }
    }
    BarText { x: 16; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.level * 100) + "%"; font.pixelSize: 18; font.weight: Font.Bold; color: BarStyle.onAccent }
    BarIcon { anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } name: root.charging ? "bolt" : "battery_full"; size: 22; fill: 1; color: BarStyle.text }
}
