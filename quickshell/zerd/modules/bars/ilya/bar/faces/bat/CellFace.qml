import QtQuick
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
    readonly property color tone: charging ? "#7bd88f" : (level < 0.15 ? "#ff6b63" : (level < 0.30 ? "#f5b85a" : ThemeBackend.text))

    property bool isFaceVisible: true
    property real targetLength: row.implicitWidth + 24
    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : 0

    Rectangle {
        id: plate
        anchors.centerIn: parent
        height: 28
        width: parent.width
        radius: 14
        color: ma.containsMouse ? Qt.alpha(ThemeBackend.text, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7

            // a plain battery glyph for the level, with a bolt version while charging
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.ready) return "power"
                    if (root.charging) return "battery_charging_full"
                    const n = Math.min(6, Math.floor(root.level * 7))
                    return root.level > 0.95 ? "battery_full" : "battery_" + n + "_bar"
                }
                font.family: "Material Symbols Rounded"
                font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 1 })
                font.pixelSize: 20
                color: root.tone
                renderType: Text.NativeRendering
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.ready ? Math.round(root.level * 100) + "%" : "AC"
                color: root.tone
                font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                renderType: Text.NativeRendering
            }
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
