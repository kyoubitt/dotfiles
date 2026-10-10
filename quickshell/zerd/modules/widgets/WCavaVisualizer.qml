import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// A 360-degree radial cava spectrum ring - 32 bars, one per cava output
// value, drawn extending outward from innerRadius. Meant to wrap around a
// circular album-art image in WMediaCard.qml, but has no dependency on it.
Item {
    id: root

    property int barCount: 32
    property var levels: []
    property color barColor: "#D4A373"
    property real innerRadius: Math.min(width, height) / 2 - maxBarLength
    property real maxBarLength: 18
    property real barWidth: 2

    Process {
        id: cavaProc
        running: true
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/widgets_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";")
                    .filter(s => s.length > 0)
                    .map(s => parseInt(s.trim()))
                    .filter(n => !isNaN(n))
                if (parts.length > 0) root.levels = parts
            }
        }
    }

    onLevelsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (root.levels.length === 0) return

            const cx = width / 2
            const cy = height / 2
            const n = root.barCount
            ctx.strokeStyle = root.barColor
            ctx.lineWidth = root.barWidth
            ctx.lineCap = "round"

            for (let i = 0; i < n; i++) {
                const level = (root.levels[i] ?? 0) / 100
                const barLen = level * root.maxBarLength
                if (barLen < 0.5) continue

                const angle = i * (2 * Math.PI / n) - Math.PI / 2
                const x1 = cx + Math.cos(angle) * root.innerRadius
                const y1 = cy + Math.sin(angle) * root.innerRadius
                const x2 = cx + Math.cos(angle) * (root.innerRadius + barLen)
                const y2 = cy + Math.sin(angle) * (root.innerRadius + barLen)

                ctx.globalAlpha = 0.5 + level * 0.5
                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.stroke()
            }
        }
    }
}
