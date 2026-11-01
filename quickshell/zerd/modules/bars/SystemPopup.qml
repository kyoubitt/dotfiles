import QtQuick
import Quickshell.Io
import qs.services

// Gauges for cpu, memory, gpu and temperature, the busiest processes, disk and uptime.
Column {
    id: root

    property var procs: []
    property string disk: ""
    property string uptime: ""
    spacing: 14

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "ps -eo comm=,pcpu= --sort=-pcpu | head -3; echo ---; df -h / | awk 'NR==2{print $3\" of \"$2}'; echo ---; uptime -p | sed 's/^up //'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n")
                root.procs = (parts[0] ?? "").split("\n").filter(l => l.trim().length > 0).map(l => {
                    const m = /^(.*\S)\s+([\d.]+)$/.exec(l.trim())
                    return m ? { name: m[1], cpu: m[2] } : null
                }).filter(x => x)
                root.disk = (parts[1] ?? "").trim()
                root.uptime = (parts[2] ?? "").trim()
            }
        }
    }
    Timer { interval: 5000; repeat: true; running: true; onTriggered: probe.running = true }

    Row {
        spacing: 12
        BarRing { value: ResourceUsage.cpuUsage; icon: "memory"; text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
        BarRing { value: ResourceUsage.memoryUsedPercentage; icon: "developer_board"; text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" }
        BarRing { visible: ResourceUsage.gpuAvailable; value: ResourceUsage.gpuUsage; icon: "videogame_asset"; text: Math.round(ResourceUsage.gpuUsage * 100) + "%" }
        BarRing { value: ResourceUsage.tempPercentage; icon: "thermostat"; text: Math.round(ResourceUsage.cpuTemp) + "°"; tint: ResourceUsage.tempPercentage > ResourceUsage.tempWarningThreshold ? BarStyle.danger : BarStyle.accent }
    }

    Column {
        visible: root.procs.length > 0
        spacing: 4
        BarText { text: "Busiest"; color: BarStyle.subtext; font.pixelSize: 11 }
        Repeater {
            model: root.procs
            delegate: Row {
                required property var modelData
                BarText { width: 220; text: modelData.name; elide: Text.ElideRight }
                BarText { width: 60; text: modelData.cpu + "%"; horizontalAlignment: Text.AlignRight; color: BarStyle.subtext }
            }
        }
    }

    Row {
        spacing: 16
        Row { spacing: 6; BarIcon { name: "hard_drive"; size: 16; color: BarStyle.subtext } BarText { text: root.disk; font.pixelSize: 12 } }
        Row { spacing: 6; BarIcon { name: "schedule"; size: 16; color: BarStyle.subtext } BarText { text: root.uptime; font.pixelSize: 12 } }
    }
}
