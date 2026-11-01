import QtQuick
import qs.modules.bars
import qs.modules.music

// A progress line that waves where it has played and goes straight where it has not (it only moves while playing).
Item {
    id: root
    property real progress: 0            // 0 to 1
    property bool playing: false
    property color tint: MusicStore.accent
    property color rest: Qt.rgba(1, 1, 1, 0.22)
    signal seek(real fraction)
    implicitHeight: 24
    property real phase: 0

    Timer { interval: 33; repeat: true; running: root.playing && root.visible; onTriggered: { root.phase += 0.16; canvas.requestPaint() } }
    onProgressChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        onPaint: {
            const c = getContext("2d"); c.clearRect(0, 0, width, height)
            const pad = 7, span = Math.max(1, width - 2 * pad)
            const mid = height / 2, x = pad + span * Math.max(0, Math.min(1, root.progress))
            c.lineCap = "round"; c.lineWidth = 4
            c.strokeStyle = String(root.rest); c.beginPath(); c.moveTo(x, mid); c.lineTo(width - pad, mid); c.stroke()
            c.strokeStyle = String(root.tint); c.beginPath()
            const amp = root.playing ? 3.2 : 0.8
            for (let px = pad; px <= x; px += 2) {
                const y = mid + Math.sin((px - pad) / 9 - root.phase) * amp * Math.min(1, (px - pad) / 10)
                if (px === pad) c.moveTo(px, y); else c.lineTo(px, y)
            }
            c.stroke()
            c.fillStyle = String(root.tint); c.beginPath(); c.arc(x, mid, 6, 0, 2 * Math.PI); c.fill()
        }
    }
    MouseArea { anchors.fill: parent; onClicked: m => root.seek(Math.max(0, Math.min(1, (m.x - 7) / Math.max(1, width - 14)))) }
}
