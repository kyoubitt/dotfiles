import QtQuick
import qs.services

// CPU, memory and (when present) GPU as percentages.
BarPill {
    id: root

    interactive: true
    tip: "System"
    onClicked: openPopup("system")
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    component Stat: Grid {
        property string icon
        property real value
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        rows: root.vertical ? 2 : 1
        columns: root.vertical ? 1 : 2
        spacing: root.vertical ? 2 : 4
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        BarIcon { name: parent.icon; size: 16; color: BarStyle.subtext }
        BarText { text: Math.round(parent.value * 100) + (root.vertical ? "" : "%"); font.pixelSize: root.vertical ? 12 : BarStyle.fontSize }
    }

    Stat { icon: "memory"; value: ResourceUsage.cpuUsage }
    Stat { icon: "developer_board"; value: ResourceUsage.memoryUsedPercentage }
    Stat { visible: ResourceUsage.gpuAvailable; icon: "videogame_asset"; value: ResourceUsage.gpuUsage }
}
