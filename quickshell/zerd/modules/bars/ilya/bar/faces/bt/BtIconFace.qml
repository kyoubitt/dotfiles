import QtQuick
import Quickshell.Bluetooth
import "../../../reusables"
import "../../../"
import "../../"

// Bluetooth on the bar: one round icon, accent while the adapter is on, dim when off. Click opens the bluetooth page of the network popup.
BarFaceBase {
    id: root
    readonly property bool on: isPreview ? true : (Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false)
    property bool isFaceVisible: true
    implicitWidth: 40
    implicitHeight: parent ? parent.height : 0

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 30; radius: 15
        color: ma.containsMouse ? Qt.alpha(ThemeBackend.text, 0.10) : "transparent"
        border.width: root.on ? 1.5 : 0
        border.color: Qt.alpha(ThemeBackend.blue, 0.85)
        Behavior on border.width { NumberAnimation { duration: 140 } }
        Behavior on color { ColorAnimation { duration: 140 } }
        Text {
            anchors.centerIn: parent
            text: root.on ? "bluetooth" : "bluetooth_disabled"
            font.family: "Material Symbols Rounded"
            font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": 0 })
            font.pixelSize: 18
            color: root.on ? ThemeBackend.blue : ThemeBackend.subtext0
            renderType: Text.NativeRendering
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Popups.toggle("bt", root) }
}
