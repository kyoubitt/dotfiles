import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions

// Notification centre: do-not-disturb switch, clear all, and one card per
// notification with its icon, text, age and actions. Click a card to expand it.
Column {
    id: root

    // The service list; a test can pass its own.
    property var items: { Notifications.revision; return Array.from(Notifications.list) }
    // Inside a titled section: no second title, and no do-not-disturb switch (the quick panel has it).
    property bool compact: false
    spacing: 10
    width: 340
    Component.onCompleted: Notifications.markAllRead()

    Item {
        width: parent.width
        height: 30
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            BarText { visible: !root.compact; anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.weight: Font.DemiBold; font.pixelSize: 15 }
            Rectangle {
                visible: root.items.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: countText.implicitWidth + 12; height: 18; radius: 9; color: BarStyle.accent
                BarText { id: countText; anchors.centerIn: parent; text: root.items.length; font.pixelSize: 11; color: BarStyle.onAccent; font.weight: Font.DemiBold }
            }
        }
        Row {
            anchors.right: parent.right
            spacing: 6
            Rectangle {
                visible: !root.compact
                width: 30; height: 30; radius: 15
                color: Notifications.silent ? BarStyle.accent : BarStyle.plateHover
                Behavior on color { ColorAnimation { duration: 110 } }
                BarIcon { anchors.centerIn: parent; name: Notifications.silent ? "notifications_off" : "notifications"; size: 16; fill: 1; color: Notifications.silent ? BarStyle.onAccent : BarStyle.subtext }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.toggleSilent() }
            }
            Rectangle {
                visible: root.items.length > 0
                width: clearText.implicitWidth + 20; height: 30; radius: 15; color: BarStyle.plateHover
                BarText { id: clearText; anchors.centerIn: parent; text: "Clear all"; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.discardAllNotifications() }
            }
        }
    }

    Column {
        visible: root.items.length === 0
        width: parent.width
        spacing: 6
        topPadding: 18; bottomPadding: 18
        BarIcon { anchors.horizontalCenter: parent.horizontalCenter; name: Notifications.silent ? "notifications_off" : "notifications_none"; size: 34; color: BarStyle.subtext }
        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: Notifications.silent ? "Do not disturb is on" : "You're all caught up"; color: BarStyle.subtext }
    }

    Flickable {
        visible: root.items.length > 0
        width: parent.width
        height: Math.min(list.implicitHeight, 420)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 6
            Repeater {
                // Only the first 30 are shown, so only those are built; a stable id keeps cards alive when the list changes.
                model: ScriptModel { objectProp: "notificationId"; values: root.items.slice(0, 30) }
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    property bool expanded: false
                    readonly property bool critical: String(modelData.urgency).toLowerCase() === "critical"
                    visible: index < 30
                    width: list.width
                    height: visible ? content.implicitHeight + 20 : 0
                    radius: BarStyle.radiusSmall
                    color: cardAreaHv.hovered ? Qt.lighter(BarStyle.plateHover, 1.15) : BarStyle.plateHover
                    border.width: critical ? 1 : 0
                    border.color: BarStyle.danger
                    Behavior on color { ColorAnimation { duration: 100 } }
                    clip: true

                    MouseArea { id: cardArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.expanded = !card.expanded }

                    HoverHandler { id: cardAreaHv }

                    Row {
                        id: content
                        x: 10; y: 10
                        spacing: 10
                        width: card.width - 20
                        NotifIcon {
                            size: 32
                            appName: card.modelData.appName
                            appIcon: card.modelData.appIcon
                            summary: card.modelData.summary
                            image: card.modelData.image
                            critical: card.critical
                        }
                        Column {
                            width: parent.width - 32 - 22 - 20
                            spacing: 1
                            Row {
                                spacing: 6
                                BarText { text: card.modelData.appName; font.pixelSize: 11; color: BarStyle.subtext; width: Math.min(implicitWidth, 150); elide: Text.ElideRight }
                                BarText { text: NotificationUtils.getFriendlyNotifTimeString(card.modelData.time); font.pixelSize: 11; color: BarStyle.subtext }
                            }
                            BarText { width: parent.width; text: card.modelData.summary; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text {
                                visible: card.modelData.body.length > 0
                                width: parent.width
                                text: card.modelData.body
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: card.expanded ? 8 : 2
                                elide: Text.ElideRight
                                color: BarStyle.subtext
                                font.pixelSize: 12
                                font.family: Appearance.font.family.expressive
                                renderType: Text.QtRendering
                            }
                            Row {
                                visible: card.modelData.actions.length > 0
                                topPadding: 6
                                spacing: 6
                                Repeater {
                                    model: card.modelData.actions.slice(0, 3)
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: actText.implicitWidth + 18; height: 26; radius: 13
                                        color: BarStyle.accent
                                        BarText { id: actText; anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: 11; color: BarStyle.onAccent }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.attemptInvokeAction(card.modelData.notificationId, parent.modelData.identifier) }
                                    }
                                }
                            }
                        }
                        Item {
                            width: 22; height: 22
                            BarIcon { anchors.centerIn: parent; name: "close"; size: 14; color: BarStyle.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.discardNotification(card.modelData.notificationId) }
                        }
                    }
                }
            }
        }
    }
}
