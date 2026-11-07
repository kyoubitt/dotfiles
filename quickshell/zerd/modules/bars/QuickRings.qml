// Rings after end-4/dots-hyprland's CircularProgress (GPL-3.0): the track is an arc with a gap either side of the value.
import QtQuick
import QtQuick.Shapes
import qs.services

// Processor, memory, graphics card and temperature at a glance, one ring each on a card.
BarCard {
    id: root

    pad: 14
    readonly property int count: ResourceUsage.gpuAvailable ? 4 : 3
    Component.onCompleted: ResourceUsage.keepAlive()
    Component.onDestruction: ResourceUsage.releaseKeepAlive()

    component Ring: Item {
        id: ring

        property real value: 0
        property string icon: ""
        property string label: ""
        property string text: ""
        property color tint: BarStyle.accent
        readonly property int size: 56
        readonly property real lineWidth: 5
        readonly property real gap: 20
        property real degree: Math.max(0, Math.min(1, value)) * 360
        Behavior on degree { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

        width: Math.floor(root.width > 0 ? (root.width - 2 * root.pad) / root.count : size)
        height: size + 38

        Item {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            width: ring.size; height: ring.size
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.tint(BarStyle.cardHigh, Qt.rgba(ring.tint.r, ring.tint.g, ring.tint.b, 0.2))
                    strokeWidth: ring.lineWidth
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: dial.width / 2; centerY: dial.height / 2
                        radiusX: dial.width / 2 - ring.lineWidth / 2 - 1; radiusY: dial.height / 2 - ring.lineWidth / 2 - 1
                        startAngle: -90 - ring.gap
                        sweepAngle: -Math.max(0, 360 - ring.degree - 2 * ring.gap)
                    }
                }
                ShapePath {
                    strokeColor: ring.tint
                    strokeWidth: ring.lineWidth
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: dial.width / 2; centerY: dial.height / 2
                        radiusX: dial.width / 2 - ring.lineWidth / 2 - 1; radiusY: dial.height / 2 - ring.lineWidth / 2 - 1
                        startAngle: -90
                        sweepAngle: ring.degree
                    }
                }
            }
            BarIcon { anchors.centerIn: parent; name: ring.icon; size: 20; fill: 1; color: ring.tint }
        }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; y: ring.size + 4; text: ring.text; font.pixelSize: 13; font.weight: Font.DemiBold }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; y: ring.size + 21; text: ring.label; font.pixelSize: 11; color: BarStyle.subtext }
    }

    Row {
        Ring { value: ResourceUsage.cpuUsage; icon: "memory"; label: "CPU"; text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
        Ring { value: ResourceUsage.memoryUsedPercentage; icon: "developer_board"; label: "Memory"; text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" }
        Ring { visible: ResourceUsage.gpuAvailable; value: ResourceUsage.gpuUsage; icon: "videogame_asset"; label: "GPU"; text: Math.round(ResourceUsage.gpuUsage * 100) + "%" }
        Ring { value: ResourceUsage.tempPercentage; icon: "thermostat"; label: "Temp"; text: Math.round(ResourceUsage.cpuTemp) + "°"; tint: ResourceUsage.tempPercentage > ResourceUsage.tempWarningThreshold ? BarStyle.danger : BarStyle.accent }
    }
}
