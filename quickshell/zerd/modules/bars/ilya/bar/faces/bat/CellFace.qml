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
        color: ma.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7

            // the cell
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 25; height: 12
                Rectangle {
                    id: shell
                    width: 22; height: 12; radius: 3.5
                    color: "transparent"
                    border.width: 1.5; border.color: Qt.alpha(root.tone, 0.85)
                    Rectangle {
                        x: 2.5; y: 2.5
                        height: parent.height - 5
                        width: Math.max(2, (parent.width - 5) * root.level)
                        radius: 1.5
                        color: root.tone
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        visible: root.charging
                        anchors.centerIn: parent
                        text: "bolt"
                        font.family: "Material Symbols Rounded"
                        font.variableAxes: ({ "wght": 700, "opsz": 20, "FILL": 1 })
                        font.pixelSize: 11
                        color: ThemeBackend.crust
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle {
                    x: 22.5; y: 3.5; width: 2.5; height: 5; radius: 1
                    color: Qt.alpha(root.tone, 0.85)
                }
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
