import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One dot per workspace on this output; the active one stretches and takes
// the accent colour. Click to switch.
BarPill {
    id: root

    property string output: ""
    property string style: Config.options?.bars?.top?.workspaceStyle ?? "pills"
    readonly property var list: (NiriService.allWorkspaces ?? []).filter(ws => ws.output === root.output)
    function iconFor(app: string): string { return AppSearch.lookupDesktopEntry(app)?.icon || AppSearch.guessIcon(app) }

    Repeater {
        model: root.list
        delegate: Item {
            id: dot
            required property var modelData
            readonly property bool active: modelData.is_active
            // the apps open here, for the "icons" style (up to three; an empty workspace is a small dot)
            readonly property var apps: root.style === "icons" ? (NiriService.windows ?? []).filter(w => w.workspace_id === modelData.id).slice(0, 3) : []
            readonly property bool iconStyle: root.style === "icons" && apps.length > 0
            implicitWidth: iconStyle ? Math.max(24, iconRow.implicitWidth + 12) : root.style === "numbers" ? 20 : root.vertical ? 10 : (active ? 28 : 12)
            implicitHeight: iconStyle ? 22 : root.style === "numbers" ? 20 : root.vertical ? (active ? 28 : 12) : 10

            Row {
                id: iconRow
                visible: dot.iconStyle
                anchors.centerIn: parent
                spacing: 3
                opacity: dot.active ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Repeater {
                    model: dot.apps
                    delegate: SmartAppIcon { required property var modelData; icon: root.iconFor(modelData.app_id ?? ""); iconSize: 16 }
                }
            }
            // under the active workspace's icons
            Rectangle {
                visible: dot.iconStyle && dot.active
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -3 }
                width: parent.width - 8; height: 2; radius: 1; color: BarStyle.accent
            }

            BarText {
                visible: root.style === "numbers"
                anchors.centerIn: parent
                text: dot.modelData.idx
                color: dot.active ? BarStyle.accent : BarStyle.subtext
                font.weight: dot.active ? Font.Bold : Font.Medium
            }
            Rectangle {
                visible: root.style !== "numbers" && !dot.iconStyle
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                antialiasing: true
                color: dot.active ? BarStyle.accent : (dot.modelData.active_window_id ? BarStyle.text : BarStyle.subtext)
                opacity: dot.active ? 1 : (dot.modelData.active_window_id ? 0.75 : 0.4)
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: NiriService.switchToWorkspace(dot.modelData.idx)
            }
            BarTip { text: "Workspace " + dot.modelData.idx }
        }
    }
}
