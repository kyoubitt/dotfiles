import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.iris.dock

// Every tray icon with its name. Left click activates, right click opens the menu,
// the eye keeps an icon out of the bar (it stays here).
Column {
    id: root

    property var window: null
    readonly property var hiddenIds: Config.options?.bars?.top?.trayHidden ?? []
    spacing: 8
    width: 300

    function setHidden(id: string, hide: bool): void {
        const list = root.hiddenIds.filter(x => x !== id)
        if (hide) list.push(id)
        Config.options.bars.top.trayHidden = list
    }

    BarText { text: "Tray"; font.weight: Font.DemiBold; font.pixelSize: 15 }
    BarText { visible: SystemTray.items.values.length === 0; text: "Nothing in the tray"; color: BarStyle.subtext }

    Repeater {
        model: SystemTray.items.values
        delegate: Item {
            id: row
            required property var modelData
            readonly property bool hidden: root.hiddenIds.includes(modelData.id)
            width: root.width; height: 38
            Rectangle { anchors.fill: parent; radius: 12; color: area.containsMouse ? BarStyle.plateHover : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
            IconImage { id: glyph; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; source: row.modelData.icon; mipmap: true; visible: status !== Image.Error && source.toString().length > 0 }
            BarIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "apps"; size: 20; color: BarStyle.subtext; visible: !glyph.visible }
            Column {
                x: 42; anchors.verticalCenter: parent.verticalCenter; width: 190
                BarText { width: parent.width; text: row.modelData.tooltipTitle || row.modelData.title || row.modelData.id; elide: Text.ElideRight }
                BarText { visible: text.length > 0; width: parent.width; font.pixelSize: 11; color: BarStyle.subtext; elide: Text.ElideRight
                    text: row.hidden ? "Hidden from the bar" : "" }
            }
            QsMenuAnchor {
                id: menu
                menu: row.modelData.menu
                anchor.window: root.window
                anchor.item: row
                anchor.edges: Edges.Right
                anchor.gravity: Edges.Right
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || row.modelData.onlyMenu) { if (row.modelData.hasMenu) menu.open() }
                    else row.modelData.activate()
                }
            }
            Item {
                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28
                BarIcon { anchors.centerIn: parent; name: row.hidden ? "visibility_off" : "visibility"; size: 16; color: row.hidden ? BarStyle.subtext : BarStyle.text }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setHidden(row.modelData.id, !row.hidden) }
            }
        }
    }
}
