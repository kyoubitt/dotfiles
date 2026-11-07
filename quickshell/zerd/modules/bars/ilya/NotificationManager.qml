pragma Singleton
import QtQuick
import qs.services as Svc

// Feeds his notification list from zerd's own notification history.
QtObject {
    id: root

    property bool sysPanelOpen: false
    property var liveNotifs: ({})
    readonly property ListModel groupedHistory: ListModel {}

    function rebuild() {
        const groups = {};
        const order = [];
        for (const n of Svc.Notifications.list) {
            const key = (n.appName || "system").toLowerCase();
            if (!groups[key]) { groups[key] = { name: n.appName || "System", icon: n.appIcon, members: [], latest: n }; order.push(key); }
            const g = groups[key];
            if (n.time >= g.latest.time) g.latest = n;
            g.members.push({
                appName: n.appName, summary: n.summary, body: n.body, iconPath: n.appIcon, image: n.image, imagePath: "",
                actionsJson: "[]", hasActions: false, uid: n.notificationId, notif: null, timestamp: n.time,
                urgency: n.urgency === "critical" ? 2 : 1, read: true
            });
        }
        groupedHistory.clear();
        for (const key of order) {
            const g = groups[key];
            groupedHistory.append({
                groupKey: key, displayName: g.name, icon: g.icon, count: g.members.length, unreadCount: 0,
                latestSummary: g.latest.summary, latestBody: g.latest.body, latestTimestamp: g.latest.time,
                itemsJson: JSON.stringify(g.members)
            });
        }
    }

    property Connections feed: Connections {
        target: Svc.Notifications
        function onListChanged() { root.rebuild() }
        function onRevisionChanged() { root.rebuild() }
    }
    Component.onCompleted: rebuild()

    function markGroupRead(groupKey) {}
    function dismissNotification(uid) { Svc.Notifications.discardNotification(uid); }
    function dismissGroup(groupKey) {
        for (const n of Svc.Notifications.list.slice()) if ((n.appName || "system").toLowerCase() === groupKey) Svc.Notifications.discardNotification(n.notificationId);
    }
    function dismissAll() { Svc.Notifications.discardAllNotifications(); }
    function clearNotifications() { Svc.Notifications.discardAllNotifications(); }
}
