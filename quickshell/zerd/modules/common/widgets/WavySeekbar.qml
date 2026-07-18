import QtQuick

Item {
    id: root

    property real progress: 0
    property color accentColor: "white"
    property color dimColor: "gray"
    property bool animate: true
    property real amplitude: 3
    property real wavelength: 9

    signal seekRequested(real fraction)

    implicitHeight: 18

    property real _phase: 0
    Timer {
        interval: 16
        running: root.animate
        repeat: true
        onTriggered: {
            root._phase += 0.06
            waveCanvas.requestPaint()
        }
    }

    Canvas {
        id: waveCanvas
        anchors.fill: parent

        onWidthChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections {
            target: root
            function onProgressChanged() { waveCanvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const midY = h / 2
            const progressX = w * root.progress

            function waveY(x) {
                return midY + Math.sin(x / root.wavelength + root._phase) * root.amplitude
            }

            ctx.strokeStyle = root.dimColor
            ctx.lineWidth = 1.5
            ctx.beginPath()
            for (let x = 0; x <= w; x += 2) {
                if (x === 0) ctx.moveTo(x, waveY(x))
                else ctx.lineTo(x, waveY(x))
            }
            ctx.stroke()

            ctx.strokeStyle = root.accentColor
            ctx.lineWidth = 2
            ctx.beginPath()
            for (let x2 = 0; x2 <= progressX; x2 += 2) {
                if (x2 === 0) ctx.moveTo(x2, waveY(x2))
                else ctx.lineTo(x2, waveY(x2))
            }
            ctx.stroke()

            ctx.fillStyle = root.accentColor
            ctx.beginPath()
            ctx.arc(progressX, waveY(progressX), 4, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.seekRequested(Math.max(0, Math.min(1, mouse.x / width)))
    }
}
