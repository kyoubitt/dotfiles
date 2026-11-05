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
            BarButton {
                id: dndBtn
                visible: !root.compact
                tone: "tonal"; toggled: Notifications.silent
                width: 34; height: 34; radius: 17
                onTapped: Notifications.toggleSilent()
                BarIcon { anchors.centerIn: parent; name: Notifications.silent ? "notifications_off" : "notifications"; size: 18; fill: Notifications.silent ? 1 : 0; color: dndBtn.ink }
            }
            BarButton {
                visible: root.items.length > 0
                tone: "tonal"
                width: clearText.implicitWidth + 24; height: 34; radius: 17
                onTapped: Notifications.discardAllNotifications()
                BarText { id: clearText; anchors.centerIn: parent; text: "Clear all"; font.pixelSize: 12; font.weight: Font.Medium }
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

    // One card per app, newest first: the two latest notifications while closed, up to eight when open.
    readonly property var groups: {
        const m = {}
        for (const n of root.items) {
            const g = m[n.appName] ?? (m[n.appName] = { app: n.appName, items: [], time: 0 })
            g.items.push(n)
            if ((n.time ?? 0) > g.time) g.time = n.time ?? 0
        }
        const out = Object.values(m)
        for (const g of out) g.items.sort((a, b) => (b.time ?? 0) - (a.time ?? 0))
        return out.sort((a, b) => b.time - a.time)
    }
    function ageOf(t: real): string {
        const ms = Date.now() - (t > 1e12 ? t : t * 1000)
        const m = Math.floor(ms / 60000)
        return m < 1 ? "Now" : m < 60 ? m + "m" : m < 1440 ? Math.floor(m / 60) + "h" : "Yesterday"
    }
    property int tick: 0
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.tick++ }

    Flickable {
        visible: root.items.length > 0
        width: parent.width
        height: Math.min(list.implicitHeight, 460)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 8
            Repeater {
                model: ScriptModel { objectProp: "app"; values: root.groups.slice(0, 12) }
                delegate: BarCard {
                    id: group
                    required property var modelData
                    property bool expanded: false
                    readonly property var items: modelData.items
                    readonly property bool critical: items.some(n => String(n.urgency).toLowerCase() === "critical")
                    width: list.width
                    pad: 12
                    color: critical ? Qt.tint(BarStyle.card, Qt.rgba(BarStyle.danger.r, BarStyle.danger.g, BarStyle.danger.b, 0.14)) : BarStyle.card
                    Behavior on implicitHeight { NumberAnimation { duration: BarStyle.motionFast; easing.type: Easing.OutCubic } }
                    clip: true

                    // the group header: icon, app, count, age, close
                    Item {
                        id: head
                        width: parent.width; height: 40
                        NotifIcon {
                            id: gIcon
                            size: 36
                            appName: group.modelData.app
                            appIcon: group.items[0].appIcon
                            summary: group.items[0].summary
                            image: ""
                            critical: group.critical
                        }
                        Column {
                            x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 46 - 70
                            BarText { text: group.modelData.app; width: parent.width; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold }
                            BarText { text: group.items.length > 1 ? group.items.length + " notifications" : "1 notification"; font.pixelSize: 11; color: BarStyle.subtext }
                        }
                        Row {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            BarText { anchors.verticalCenter: parent.verticalCenter; text: { void root.tick; return root.ageOf(group.modelData.time) } font.pixelSize: 11; color: BarStyle.subtext }
                            BarIcon { anchors.verticalCenter: parent.verticalCenter; name: group.expanded ? "expand_less" : "expand_more"; size: 20; color: BarStyle.subtext }
                        }
                    }
                    // the notifications
                    Column {
                        y: 48; width: parent.width; spacing: group.expanded ? 6 : 3
                        Repeater {
                            model: group.items.slice(0, group.expanded ? 8 : 2)
                            delegate: Item {
                                id: row
                                required property var modelData
                                required property int index
                                readonly property var buttons: (modelData.actions ?? []).filter(a => a.text && a.text.length > 0 && a.identifier !== "default").slice(0, 3)
                                width: parent.width
                                height: rowCol.implicitHeight + 8
                                opacity: !group.expanded && index === 1 && group.items.length > 2 ? 0.55 : 1
                                Column {
                                    id: rowCol
                                    x: 4; y: 4; width: parent.width - 8 - 26; spacing: 2
                                    BarText { width: parent.width; elide: Text.ElideRight; text: row.modelData.summary.length > 0 ? row.modelData.summary : row.modelData.appName; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        visible: row.modelData.body.length > 0
                                        width: parent.width
                                        text: row.modelData.body; textFormat: Text.PlainText
                                        wrapMode: Text.Wrap; maximumLineCount: group.expanded ? 6 : 1; elide: Text.ElideRight
                                        color: BarStyle.subtext; font.pixelSize: 12; font.family: Appearance.font.family.expressive
                                        renderType: Text.QtRendering
                                    }
                                    NotifActions {
                                        visible: group.expanded && row.buttons.length > 0
                                        width: parent.width
                                        notificationId: row.modelData.notificationId
                                        appName: row.modelData.appName
                                        buttons: row.buttons
                                    }
                                }
                                // dismiss this one
                                BarButton {
                                    id: dismissBtn
                                    visible: group.expanded
                                    tone: "plain"; width: 24; height: 24; radius: 12
                                    anchors { right: parent.right; top: parent.top; topMargin: 2 }
                                    onTapped: Notifications.discardNotification(row.modelData.notificationId)
                                    BarIcon { anchors.centerIn: parent; name: "close"; size: 14; color: dismissBtn.inkSoft }
                                }
                            }
                        }
                    }
                    // click opens / closes the group, middle-click dismisses it, drag sideways dismisses it
                    MouseArea {
                        anchors.fill: parent; z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) { for (const n of group.items.slice()) Notifications.discardNotification(n.notificationId) }
                            else group.expanded = !group.expanded
                        }
                    }
                    DragHandler {
                        yAxis.enabled: false; target: null
                        onActiveChanged: if (!active && Math.abs(translation.x) > 70) { for (const n of group.items.slice()) Notifications.discardNotification(n.notificationId) }
                    }
                }
            }
        }
    }
}
