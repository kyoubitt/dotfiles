import QtQuick
import qs.services as Svc
import "../../../reusables"
import "../../../"
import "../../"

// Do Not Disturb with the unread count. Left click mutes or unmutes notifications, right click opens the notification list.
BarFaceBase {
    id: root

    readonly property bool silent: Svc.Notifications.silent
    readonly property int unread: Svc.Notifications.unread

    readonly property real btn: 28
    property real targetLength: btn + 12
    property bool isFaceVisible: true

    implicitWidth: targetLength
    implicitHeight: parent ? parent.height : 0

    Rectangle {
        id: disc
        width: root.btn
        height: root.btn
        radius: root.btn / 2
        anchors.centerIn: parent
        color: root.silent ? Qt.alpha(ThemeBackend.blue, 0.22) : (ma.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            renderType: Text.NativeRendering
            anchors.centerIn: parent
            text: root.silent ? "notifications_off" : "notifications"
            font.family: "Material Symbols Rounded"
            font.variableAxes: ({ "wght": 600, "opsz": 20 })
            font.pixelSize: 18
            color: root.silent ? ThemeBackend.blue : ThemeBackend.text
        }

        Rectangle {
            visible: root.unread > 0 && !root.silent
            width: Math.max(14, badge.implicitWidth + 6)
            height: 14
            radius: 7
            x: parent.width - width + 2
            y: -2
            color: ThemeBackend.blue
            Text {
                id: badge
                renderType: Text.NativeRendering
                anchors.centerIn: parent
                text: root.unread > 99 ? "99+" : String(root.unread)
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                color: ThemeBackend.crust
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) Popups.toggle("notifications", root);
            else Svc.Notifications.toggleSilent();
        }
    }
}
