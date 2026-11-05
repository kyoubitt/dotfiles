import QtQuick
import qs.services
import qs.modules.common.widgets

// The notification centre: iNiR's own list (groups per app, expand, swipe away) with its status row (do not disturb,
// count, clear all).
Item {
    id: root

    // Inside a titled section the panel is a little shorter.
    property bool compact: false
    width: 360
    height: compact ? 420 : 520
    Component.onCompleted: Notifications.markAllRead()

    NotificationList {
        anchors.fill: parent
    }
}
