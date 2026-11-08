import QtQuick
import QtQuick.Shapes
import "../../../reusables"
import "../../../"
import "../../"

// CPU and memory as two compact meters: a short label, the number, and a thin bar along the bottom.
// Above 85 % the number and the bar turn to the warning colour. A click opens the system monitor.
BarFaceBase {
    id: root

    readonly property real meterW: 56
    readonly property real gapW: 12
    property real targetLength: 2 * meterW + gapW + 20
    property bool isFaceVisible: true

    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : 0

    Component.onCompleted: SysData.subscribe()
    Component.onDestruction: SysData.unsubscribe()

    // one resource, drawn after iNiR's bar resources: a thin ring that fills with the load, a glyph inside it, the number beside it
    component Meter: Item {
        id: meter
        property string label
        property string glyph
        property int value
        readonly property bool hot: value >= 85
        readonly property color tone: hot ? ThemeBackend.red : ThemeBackend.text
        width: root.meterW
        height: 28

        Item {
            id: ringBox
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.16)
                    strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: meter.hot ? ThemeBackend.red : ThemeBackend.blue
                    strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: -90
                        sweepAngle: 360 * Math.max(0.02, Math.min(100, meter.value)) / 100
                        Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: meter.glyph
                font.family: "Material Symbols Rounded"
                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                font.pixelSize: 12
                color: meter.tone
                renderType: Text.NativeRendering
            }
        }
        // fixed room for three digits so the ring never moves
        Text {
            x: ringBox.width + 5
            width: 24
            anchors.verticalCenter: parent.verticalCenter
            text: meter.value
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: meter.tone
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.gapW
        Meter { label: "CPU"; glyph: "memory"; value: SysData.cpu }
        Meter { label: "RAM"; glyph: "developer_board"; value: SysData.ramPercent }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popups.toggle("sysmon", root)
    }
}
