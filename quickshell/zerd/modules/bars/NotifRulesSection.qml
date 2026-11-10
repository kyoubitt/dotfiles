import QtQuick
import qs.services
import qs.modules.common

// Every app that has sent a notification, with what happens to its banners: normal, silent (kept in the
// centre only) or muted (dropped). Pick one of the three on a row, or click the row to step through them.
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
    readonly property var modes: [{ m: "normal", t: "Normal" }, { m: "silent", t: "Silent" }, { m: "mute", t: "Muted" }]

    BarText { visible: root.apps.length === 0; text: "No apps yet. They appear once something notifies."; color: BarStyle.subtext; font.pixelSize: 12; width: root.width; wrapMode: Text.Wrap }
    Repeater {
        model: root.apps
        delegate: Item {
            id: row
            required property string modelData
            readonly property string mode: NotifRules.modeOf(modelData)
            width: root.width; height: 40
            BarHoverFill { anchors.fill: parent; hovered: rowHover.hovered; pressed: false }
            HoverHandler { id: rowHover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifRules.cycle(row.modelData) }
            BarText { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 12 - seg.width - 14; text: row.modelData; elide: Text.ElideRight }
            // the three choices as one segmented pill
            Rectangle {
                id: seg
                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                width: segRow.width + 4; height: 28; radius: 17
                color: BarStyle.cardHigh
                border.width: 1; border.color: BarStyle.edge
                Row {
                    id: segRow
                    x: 2; y: 2
                    Repeater {
                        model: root.modes
                        delegate: Rectangle {
                            id: opt
                            required property var modelData
                            readonly property bool on: row.mode === modelData.m
                            width: optText.implicitWidth + 20; height: 24; radius: 12
                            color: on ? (modelData.m === "mute" ? BarStyle.danger : BarStyle.accent) : "transparent"
                            Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
                            BarText { id: optText; anchors.centerIn: parent; text: opt.modelData.t; font.pixelSize: 11; font.weight: opt.on ? Font.DemiBold : Font.Medium; color: opt.on ? (opt.modelData.m === "mute" ? Appearance.colors.colOnError : BarStyle.onAccent) : BarStyle.subtext }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotifRules.setMode(row.modelData, opt.modelData.m) }
                        }
                    }
                }
            }
        }
    }
}
