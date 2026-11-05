import QtQuick
import qs.modules.common
import qs.services

// The buttons under a notification, the same in the banner and the centre: its own actions as tonal buttons and,
// optionally, a quiet "Mute <app>" button.
Flow {
    id: root

    property string notificationId: ""
    property string appName: ""
    property var buttons: []
    property bool showMute: false

    topPadding: 6
    spacing: 6

    Repeater {
        model: root.buttons
        delegate: BarButton {
            id: act
            required property var modelData
            tone: "tonal"
            width: actText.implicitWidth + 30; height: 34; radius: BarStyle.radiusSmall
            onTapped: Notifications.attemptInvokeAction(root.notificationId, act.modelData.identifier)
            BarText { font.family: Appearance.font.family.monospace; id: actText; anchors.centerIn: parent; text: act.modelData.text; font.pixelSize: 12; font.weight: Font.Medium; color: act.ink }
        }
    }
    BarButton {
        id: mute
        visible: root.showMute
        tone: "outlined"
        width: muteText.implicitWidth + 30; height: 34; radius: BarStyle.radiusSmall
        onTapped: NotifRules.setMode(root.appName, "silent")
        BarText { font.family: Appearance.font.family.monospace; id: muteText; anchors.centerIn: parent; text: "Mute " + root.appName; font.pixelSize: 11; color: mute.inkSoft; width: Math.min(implicitWidth, 120); elide: Text.ElideRight }
    }
}
