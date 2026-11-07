import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs

// An app's own tray menu (the DBus menu behind QsMenuOpener), drawn in the shell's look instead of a platform menu, after
// the tray menu of ilyamiro's rice (serpantinum, AGPL-3.0). A submenu replaces the list under a title row with a back
// arrow. A click runs the entry and closes the popup.
Column {
    id: root

    property string itemId: ""
    readonly property var item: (SystemTray.items.values ?? []).find(i => i.id === root.itemId) ?? null
    // the menus opened so far, outermost first: entries (submenus) whose children are showing
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (item?.menu ?? null)
    spacing: 2
    implicitWidth: Math.max(210, Math.min(340, widest + 24))
    property real widest: 0

    onItemIdChanged: stack = []

    QsMenuOpener { id: opener; menu: root.current }

    function iconSource(icon: string): string {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon
        const p = Quickshell.iconPath(icon.replace(/\.(png|svg|xpm)$/i, ""), true)
        return p ? (p.startsWith("/") ? "file://" + p : p) : ""
    }

    // back row of a submenu
    BarButton {
        visible: root.stack.length > 0
        tone: "plain"
        width: root.width; height: 36; radius: BarStyle.radiusSmall
        onTapped: root.stack = root.stack.slice(0, -1)
        Row {
            x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            BarIcon { name: "arrow_back"; size: 18; color: BarStyle.text }
            BarText { text: root.stack.length > 0 ? String(root.stack[root.stack.length - 1].text).replace(/_/g, "") : ""; font.weight: Font.DemiBold }
        }
    }

    Repeater {
        model: opener.children
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool sep: modelData.isSeparator
            readonly property string label: String(modelData.text ?? "").replace(/_(.)/g, "$1")
            readonly property string iconUrl: root.iconSource(modelData.icon ?? "")
            width: root.width
            height: sep ? 9 : 36
            implicitWidth: sep ? 0 : lead.width + labelText.implicitWidth + 40
            onImplicitWidthChanged: root.widest = Math.max(root.widest, implicitWidth)
            Component.onCompleted: root.widest = Math.max(root.widest, implicitWidth)

            Rectangle { visible: row.sep; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: BarStyle.border }
            BarHoverFill {
                visible: !row.sep && row.modelData.enabled
                anchors.fill: parent
                hovered: ma.containsMouse
                pressed: ma.pressed
            }
            Row {
                id: lead
                visible: !row.sep
                x: 10; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                // check mark / radio dot, else the entry's icon
                BarIcon {
                    visible: row.modelData.buttonType !== QsMenuButtonType.None
                    name: row.modelData.buttonType === QsMenuButtonType.RadioButton
                        ? (row.modelData.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                        : (row.modelData.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                    size: 18
                    color: row.modelData.checkState === Qt.Checked ? BarStyle.accent : BarStyle.subtext
                }
                IconImage {
                    visible: row.modelData.buttonType === QsMenuButtonType.None && row.iconUrl.length > 0
                    width: visible ? 18 : 0; height: 18
                    source: row.iconUrl
                    mipmap: true
                }
            }
            BarText {
                id: labelText
                visible: !row.sep
                x: lead.x + lead.width + (lead.width > 0 ? 8 : 0)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, row.width - x - (row.modelData.hasChildren ? 34 : 14))
                text: row.label
                elide: Text.ElideRight
                opacity: row.modelData.enabled ? 1 : 0.4
            }
            BarIcon {
                visible: !row.sep && row.modelData.hasChildren
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                name: "chevron_right"; size: 18; color: BarStyle.subtext
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                enabled: !row.sep && row.modelData.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (row.modelData.hasChildren) root.stack = root.stack.concat([row.modelData])
                    else { row.modelData.triggered(); GlobalStates.barPopup = null }
                }
            }
        }
    }
}
