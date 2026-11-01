import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.iris.dock

// Status-notifier icons: click activates, middle click is the secondary action,
// right click opens the app's menu. Extra, hidden or dock-duplicate icons sit
// behind the chevron, which opens the full tray list.
BarPill {
    id: root

    property var window: null
    readonly property var all: SystemTray.items.values
    readonly property var hiddenIds: Config.options?.bars?.top?.trayHidden ?? []
    readonly property int maxIcons: Config.options?.bars?.top?.trayMax ?? 4
    // Apps already pinned in the dock are not repeated here.
    readonly property var items: all.filter(item => !hiddenIds.includes(item.id) && !root.inDock(item))
    readonly property var shownItems: items.slice(0, maxIcons)
    visible: all.length > 0
    tip: ""

    function inDock(item: var): bool {
        const keys = [item.id, item.title].map(s => String(s ?? "").toLowerCase()).filter(s => s.length > 0)
        const pinned = IrisDockOrder.pins.map(p => String(p).toLowerCase())
        const open = IrisDockOrder.entries.map(e => String(e.appId ?? "").toLowerCase())
        return !(Config.options?.bars?.top?.trayHidePinned ?? true) ? false
            : keys.some(k => pinned.concat(open).some(p => p.length > 2 && (k.includes(p) || p.includes(k))))
    }

    Repeater {
        model: root.shownItems
        delegate: Item {
            id: entry
            required property var modelData
            implicitWidth: 20
            implicitHeight: 24

            IconImage {
                id: glyph
                anchors.centerIn: parent
                width: 18; height: 18
                source: entry.modelData.icon
                mipmap: true
                visible: status !== Image.Error && source.toString().length > 0
            }
            BarIcon { anchors.centerIn: parent; name: "apps"; size: 18; color: BarStyle.subtext; visible: !glyph.visible }
            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.window: root.window
                anchor.item: entry
                anchor.edges: root.vertical ? Edges.Right : Edges.Bottom
                anchor.gravity: root.vertical ? Edges.Right : Edges.Bottom
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && entry.modelData.onlyMenu)) {
                        if (entry.modelData.hasMenu) menu.open()
                    } else if (mouse.button === Qt.MiddleButton) entry.modelData.secondaryActivate()
                    else entry.modelData.activate()
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }
            BarTip { text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id }
        }
    }
    // More: everything in the tray, including hidden and overflow icons.
    Item {
        visible: root.all.length > root.shownItems.length
        implicitWidth: 20
        implicitHeight: 24
        BarIcon { anchors.centerIn: parent; name: "more_horiz"; size: 18; color: BarStyle.subtext }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openPopup("tray") }
        BarTip { text: "All tray icons" }
    }
}
