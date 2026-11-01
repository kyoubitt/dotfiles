import QtQuick
import qs.services

// Every app that has sent a notification, with what happens to its banners: normal, silent (kept in the
// centre only) or muted (dropped). Click a row to step through the three.
Column {
    id: root

    spacing: 2
    readonly property var apps: {
        Notifications.revision
        const seen = {}
        for (const n of Array.from(Notifications.list)) seen[n.appName] = true
        for (const r of NotifRules.raw) seen[String(r).slice(0, String(r).lastIndexOf("|"))] = true
        return Object.keys(seen).filter(a => a.length > 0).sort()
    }

    BarText { visible: root.apps.length === 0; text: "No apps yet. They appear once something notifies."; color: BarStyle.subtext; font.pixelSize: 12; width: root.width; wrapMode: Text.Wrap }
    Repeater {
        model: root.apps
        delegate: Item {
            required property string modelData
            readonly property string mode: NotifRules.modeOf(modelData)
            width: root.width; height: 34
            Rectangle { anchors.fill: parent; radius: 10; color: rowHover.hovered ? BarStyle.plateHover : "transparent" }
            HoverHandler { id: rowHover }
            BarText { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120; text: modelData; elide: Text.ElideRight }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                width: 92; height: 24; radius: 12
                color: mode === "normal" ? "transparent" : (mode === "silent" ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.22) : Qt.rgba(1, 0.41, 0.38, 0.22))
                border.width: 1; border.color: mode === "normal" ? BarStyle.border : (mode === "silent" ? BarStyle.accent : BarStyle.danger)
                BarText { anchors.centerIn: parent; text: mode === "normal" ? "Normal" : mode === "silent" ? "Silent" : "Muted"; font.pixelSize: 11 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifRules.cycle(modelData) }
        }
    }
}
