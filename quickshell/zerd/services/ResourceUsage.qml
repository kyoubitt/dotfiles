pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Lean CPU / memory / disk / iGPU / CPU-temperature sampler for the iRiS
// vitals card. Polls every 2s, and only while something has asked for it
// (keepAlive / releaseKeepAlive). The NVIDIA dGPU is deliberately never
// polled; the GPU figure comes from the AMD iGPU's sysfs counter when present.
Singleton {
    id: root

    property real cpuUsage: 0
    property real memoryUsedPercentage: 0
    property real diskUsedPercentage: 0
    property real gpuUsage: 0
    property bool gpuAvailable: false
    property real cpuTemp: 0
    readonly property real maxTemp: 100
    readonly property real tempPercentage: Math.max(0, Math.min(1, cpuTemp / maxTemp))
    readonly property real tempWarningThreshold: 0.8

    property var cpuUsageHistory: []
    property var memoryUsageHistory: []
    property var gpuUsageHistory: []
    property var cpuTempHistory: []
    property var gpuTempHistory: []

    property int _keepers: 0
    property real _prevIdle: -1
    property real _prevTotal: -1

    function keepAlive(): void { _keepers += 1 }
    function releaseKeepAlive(): void { _keepers = Math.max(0, _keepers - 1) }

    function _push(list: var, value: real): var {
        const next = list.concat([value])
        return next.length > 60 ? next.slice(next.length - 60) : next
    }

    Process {
        id: sampler
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; df -P / | tail -1; echo GPU:$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); echo TEMP:$(for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name 2>/dev/null) in k10temp|coretemp) cat $d/temp1_input; break;; esac; done)"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n")
                    const c = lines[0].trim().split(/\s+/).slice(1).map(Number)
                    const idle = c[3] + c[4]
                    const total = c.reduce((a, b) => a + b, 0)
                    if (root._prevTotal >= 0 && total > root._prevTotal)
                        root.cpuUsage = Math.max(0, Math.min(1, 1 - (idle - root._prevIdle) / (total - root._prevTotal)))
                    root._prevIdle = idle
                    root._prevTotal = total
                    root.cpuUsageHistory = root._push(root.cpuUsageHistory, root.cpuUsage)

                    const memTotal = parseInt(lines[1].split(/\s+/)[1])
                    const memAvail = parseInt(lines[2].split(/\s+/)[1])
                    root.memoryUsedPercentage = 1 - memAvail / memTotal
                    root.memoryUsageHistory = root._push(root.memoryUsageHistory, root.memoryUsedPercentage)
                    root.diskUsedPercentage = parseFloat(lines[3].trim().split(/\s+/)[4]) / 100

                    const gpu = parseFloat((lines.find(l => l.startsWith("GPU:")) ?? "GPU:").slice(4))
                    root.gpuAvailable = !isNaN(gpu)
                    if (root.gpuAvailable) {
                        root.gpuUsage = Math.max(0, Math.min(1, gpu / 100))
                        root.gpuUsageHistory = root._push(root.gpuUsageHistory, root.gpuUsage)
                    }
                    const temp = parseFloat((lines.find(l => l.startsWith("TEMP:")) ?? "TEMP:").slice(5))
                    if (!isNaN(temp)) {
                        root.cpuTemp = temp / 1000
                        root.cpuTempHistory = root._push(root.cpuTempHistory, root.tempPercentage)
                    }
                } catch (e) {
                    console.warn("[ResourceUsage] parse failed:", e)
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: root._keepers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }
}
