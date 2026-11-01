import QtQuick
import qs.services

// CPU, memory and temperature at a glance.
Row {
    id: root

    // Spread over the full width with equal gaps.
    readonly property int count: ResourceUsage.gpuAvailable ? 4 : 3
    spacing: Math.max(8, Math.floor((width - count * 64) / Math.max(1, count - 1)))
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    BarRing { diameter: 64; value: ResourceUsage.cpuUsage; icon: "memory"; text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
    BarRing { diameter: 64; value: ResourceUsage.memoryUsedPercentage; icon: "developer_board"; text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" }
    BarRing { diameter: 64; visible: ResourceUsage.gpuAvailable; value: ResourceUsage.gpuUsage; icon: "videogame_asset"; text: Math.round(ResourceUsage.gpuUsage * 100) + "%" }
    BarRing { diameter: 64; value: ResourceUsage.tempPercentage; icon: "thermostat"; text: Math.round(ResourceUsage.cpuTemp) + "°"; tint: ResourceUsage.tempPercentage > ResourceUsage.tempWarningThreshold ? BarStyle.danger : BarStyle.accent }
}
