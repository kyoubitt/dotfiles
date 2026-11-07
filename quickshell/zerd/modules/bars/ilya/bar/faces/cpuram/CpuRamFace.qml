import QtQuick
import "../../../reusables"
import "../../../"
import "../../"

// CPU and memory as two compact meters: a short label, the number, and a thin bar along the bottom.
// Above 85 % the number and the bar turn to the warning colour. A click opens the system monitor.
BarFaceBase {
    id: root

    readonly property real meterW: 58
    readonly property real gapW: 12
    property real targetLength: 2 * meterW + gapW + 20
    property bool isFaceVisible: true

    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : 0

    Component.onCompleted: SysData.subscribe()
    Component.onDestruction: SysData.unsubscribe()

    component Meter: Item {
        id: meter
        property string label
        property int value
        readonly property bool hot: value >= 85
        width: root.meterW
        height: 26

        Text {
            renderType: Text.NativeRendering
            x: 0
            y: 1
            text: meter.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            color: ThemeBackend.subtext0
        }
        // fixed room for "100%" so the number never moves its label
        Text {
            renderType: Text.NativeRendering
            x: meter.width - 34
            width: 34
            y: 0
            horizontalAlignment: Text.AlignRight
            text: meter.value + "%"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: meter.hot ? ThemeBackend.red : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Rectangle {
            x: 0
            y: meter.height - 4
            width: meter.width
            height: 3
            radius: 1.5
            color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.12)
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                color: meter.hot ? ThemeBackend.red : ThemeBackend.blue
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.gapW
        Meter { label: "CPU"; value: SysData.cpu }
        Meter { label: "RAM"; value: SysData.ramPercent }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popups.toggle("sysmon", root)
    }
}
