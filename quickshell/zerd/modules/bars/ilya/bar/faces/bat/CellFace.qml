import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import "../../../reusables"
import "../../../"
import "../../"

// The battery on the bar, our own: a drawn cell that fills with the charge (amber under 30 %, red under 15 %, a bolt while charging)
// beside the percentage. The look of the idea is Caelestia's battery in the status icons; the code is ours. Click opens the battery popup.
BarFaceBase {
    id: root

    readonly property bool ready: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
    readonly property real level: ready ? Math.max(0, Math.min(1, UPower.displayDevice.percentage)) : 0
    readonly property bool charging: ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property color tone: charging ? "#7bd88f" : (level < 0.15 ? "#ff6b63" : (level < 0.30 ? "#f5b85a" : ThemeBackend.blue))

    property bool isFaceVisible: true
    property real targetLength: 70
    implicitWidth: 70
    implicitHeight: parent ? parent.height : 0

    Item {
        id: box
        anchors.centerIn: parent
        width: 62; height: 28

        Item {
            id: ringBox
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.alpha(ThemeBackend.text, 0.16); strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: root.tone; strokeWidth: 2.2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 11; centerY: 11; radiusX: 9.4; radiusY: 9.4; startAngle: -90
                        sweepAngle: 360 * Math.max(0.02, root.ready ? root.level : 1)
                        Behavior on sweepAngle { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.charging ? "bolt" : "battery_android_full"
                font.family: "Material Symbols Rounded"
                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                font.pixelSize: 12
                color: root.charging ? root.tone : ThemeBackend.text
                renderType: Text.NativeRendering
            }
        }
        Text {
            x: ringBox.width + 5
            width: 34
            anchors.verticalCenter: parent.verticalCenter
            text: root.ready ? Math.round(root.level * 100) : "AC"
            color: root.tone
            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popups.toggle("system", root)
    }
}
