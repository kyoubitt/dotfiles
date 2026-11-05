import QtQuick
import Quickshell
import qs.services

// Per-app rules (NotifRules): an app set to "mute" never shows or stays, one set to "silent" shows nothing but is kept.
// Runs as banners arrive, a moment later and outside the change that announced them (dismissing edits that list).
Scope {
    id: root
    readonly property var raw: Notifications.popupList ?? []
    onRawChanged: sweep.restart()
    Timer {
        id: sweep
        interval: 20
        onTriggered: {
            for (const n of root.raw.slice()) {
                const mode = NotifRules.modeOf(n.appName)
                if (mode === "silent") Notifications.timeoutNotification(n.notificationId)
                else if (mode === "mute") Notifications.discardNotification(n.notificationId)
            }
        }
    }
}
