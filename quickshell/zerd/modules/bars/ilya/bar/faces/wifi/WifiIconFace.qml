import QtQuick
import Quickshell.Networking
import "../../../reusables"
import "../../../"
import "../../"

// Wi-Fi on the bar: one round icon, tinted with the accent while it is on, dim and slashed when off. Click opens the network popup.
BarFaceBase {
    id: root
    readonly property bool on: isPreview ? true : Networking.wifiEnabled
    property bool isFaceVisible: true
    implicitWidth: 40
    implicitHeight: parent ? parent.height : 0

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 30; radius: 15
        color: root.on ? Qt.alpha(ThemeBackend.blue, ma.containsMouse ? 0.32 : 0.22) : (ma.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: 140 } }
        Text {
            anchors.centerIn: parent
            text: root.on ? "wifi" : "wifi_off"
            font.family: "Material Symbols Rounded"
            font.variableAxes: ({ "wght": 600, "opsz": 20, "FILL": root.on ? 1 : 0 })
            font.pixelSize: 18
            color: root.on ? ThemeBackend.blue : ThemeBackend.subtext0
            renderType: Text.NativeRendering
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Popups.toggle("wifi", root) }
}
