import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services

// CPU / memory / root-disk / network usage, read straight from /proc and
// df - no extra daemon. CPU is a delta between two /proc/stat samples, so
// the very first reading shows 0 until a second sample lands. Network is
// summed across every non-loopback interface rather than guessing which
// one is "the" route, so it's accurate on wifi, ethernet, or both at once.
// Refreshes every 5s and CPU/network are both smoothed so the bars don't
// keep twitching.
Item {
    id: root
    // Fixed, like WWeatherCard's own 284 - not derived from a parent's
    // width. The card used to rely on the panel handing it a width
    // externally (`width: parent.width` at the usage site), which only
    // ever had something real to inherit from in the vertical layout; in
    // the horizontal bar nothing drives that width at all, so it
    // collapsed to a degenerate near-zero size instead.
    implicitWidth: 284
    implicitHeight: col.implicitHeight

    property real cpuPct: 0
    property real memPct: 0
    property real diskPct: 0
    property string memText: "--"
    property real netRxRate: 0
    property real netTxRate: 0
    property real _prevIdle: -1
    property real _prevTotal: -1
    property real _prevRx: -1
    property real _prevTx: -1

    function formatRate(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1048576) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -P / | tail -1; tail -n +3 /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    const cpu = lines[0].trim().split(/\s+/).slice(1).map(Number)
                    const idle = cpu[3] + cpu[4]
                    const total = cpu.reduce((a, b) => a + b, 0)
                    if (root._prevTotal >= 0) {
                        const dTotal = total - root._prevTotal
                        const dIdle = idle - root._prevIdle
                        if (dTotal > 0) {
                            const raw = Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100))
                            // Smoothed - raw per-sample CPU jumps around a lot
                            // and made the bar twitch on every refresh.
                            root.cpuPct = root.cpuPct * 0.6 + raw * 0.4
                        }
                    }
                    root._prevIdle = idle
                    root._prevTotal = total

                    const memTotal = parseInt(lines[1].split(/\s+/)[1])
                    const memAvail = parseInt(lines[2].split(/\s+/)[1])
                    root.memPct = (1 - memAvail / memTotal) * 100
                    root.memText = Math.round((memTotal - memAvail) / 1048576) + " / " + Math.round(memTotal / 1048576) + " GB"

                    const diskFields = lines[3].trim().split(/\s+/)
                    root.diskPct = parseFloat(diskFields[4])

                    let rx = 0, tx = 0
                    for (let i = 4; i < lines.length; i++) {
                        const parts = lines[i].trim().split(":")
                        if (parts.length < 2) continue
                        const iface = parts[0].trim()
                        if (iface === "lo") continue
                        const fields = parts[1].trim().split(/\s+/)
                        rx += parseInt(fields[0])
                        tx += parseInt(fields[8])
                    }
                    if (root._prevRx >= 0) {
                        const rawRx = Math.max(0, (rx - root._prevRx) / 5)
                        const rawTx = Math.max(0, (tx - root._prevTx) / 5)
                        root.netRxRate = root.netRxRate * 0.5 + rawRx * 0.5
                        root.netTxRate = root.netTxRate * 0.5 + rawTx * 0.5
                    }
                    root._prevRx = rx
                    root._prevTx = tx
                } catch (e) {
                    console.warn("[WSystemCard] stats parse failed:", e)
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // Four bands stacked at a fixed height each, every band centering its
    // own icon/label/bar/detail row vertically. A small icon on the left
    // of each row - CPU/RAM/DISK/NET read as nothing but a label+number
    // before, with no real identity beyond color alone.
    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: [
                { icon: "memory", label: "CPU", pct: root.cpuPct, detail: Math.round(root.cpuPct) + "%" },
                { icon: "dns", label: "RAM", pct: root.memPct, detail: root.memText },
                { icon: "storage", label: "DISK", pct: root.diskPct, detail: Math.round(root.diskPct) + "%" },
                {
                    icon: "swap_vert",
                    label: "NET",
                    // No natural 0-100% ceiling for a transfer rate - 8 MB/s
                    // is just a reasonable "this bar is visually full" cap,
                    // not a real limit.
                    pct: Math.min(100, (root.netRxRate + root.netTxRate) / 83886.08),
                    detail: "↓" + root.formatRate(root.netRxRate) + " ↑" + root.formatRate(root.netTxRate)
                }
            ]

            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 40

                ColumnLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: modelData.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 13
                            color: WallustTheme.textSecondary
                        }
                        Text {
                            text: modelData.label
                            color: WallustTheme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modelData.detail
                            color: modelData.pct > 85 ? "#E58C8C" : WallustTheme.textPrimary
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        antialiasing: true
                        color: WallustTheme.bgBase

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, modelData.pct / 100))
                            height: parent.height
                            radius: 2
                            antialiasing: true
                            color: modelData.pct > 85 ? "#E58C8C" : WallustTheme.accent
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
