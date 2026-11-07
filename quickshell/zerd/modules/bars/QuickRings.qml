// Rings after end-4/dots-hyprland's CircularProgress (GPL-3.0): the track is an arc with a gap either side of the value.
import QtQuick
import QtQuick.Shapes
import qs.services

// Processor, memory, graphics card and temperature at a glance, one ring each on a card.
BarCard {
    id: root

    pad: 14
    readonly property int count: ResourceUsage.gpuAvailable ? 4 : 3
    readonly property real cell: Math.floor(root.width > 0 ? (root.width - 2 * root.pad) / root.count : 56)
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    Row {
        QuickRing { cell: root.cell; value: ResourceUsage.cpuUsage; icon: "memory"; label: "CPU"; text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
        QuickRing { cell: root.cell; value: ResourceUsage.memoryUsedPercentage; icon: "developer_board"; label: "Memory"; text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" }
        QuickRing { cell: root.cell; visible: ResourceUsage.gpuAvailable; value: ResourceUsage.gpuUsage; icon: "videogame_asset"; label: "GPU"; text: Math.round(ResourceUsage.gpuUsage * 100) + "%" }
        QuickRing { cell: root.cell; value: ResourceUsage.tempPercentage; icon: "thermostat"; label: "Temp"; text: Math.round(ResourceUsage.cpuTemp) + "°"; tint: ResourceUsage.tempPercentage > ResourceUsage.tempWarningThreshold ? BarStyle.danger : BarStyle.accent }
    }
}
