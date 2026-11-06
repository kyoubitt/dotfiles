pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.common
import qs.modules.dock2
import qs.modules.bars

// One full-screen, click-through layer per output that carries the floating
// dock. Only the dock's own rectangle takes input; while a menu is open the
// whole layer catches clicks so one outside it closes the menu.
Scope {
    IrisLauncher {}

    Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData

        screen: modelData
        // the editors cover the whole screen, so the dock steps aside while one is open
        visible: !BarState.editingBar && !BarState.board
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors { left: true; right: true; top: true; bottom: true }

        WlrLayershell.namespace: "quickshell:zerd-iris-dock"
        // A fullscreen window stays above the Top layer; follow it so the dock
        // can still be revealed over a game.
        WlrLayershell.layer: (dock.item?.overFullscreen ?? false) ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: (dock.item?.menuOpen ?? false) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        mask: (dock.item?.menuOpen ?? false) ? null : dockRegion
        Region {
            id: dockRegion
            item: dock.item && !dock.item.inputOff ? dock.item.hitItem : null
            Region { item: ctlItem }
        }

        MouseArea {
            anchors.fill: parent
            enabled: dock.item?.menuOpen ?? false
            acceptedButtons: Qt.AllButtons
            onPressed: dock.item.closeMenu()
        }

        DockControls {
            id: ctlItem
            visible: !!dock.item && !dock.item.inputOff && (Config.options?.iris?.dock?.controls ?? []).length > 0
            screen: win.screen
            controls: Config.options?.iris?.dock?.controls ?? []
            readonly property var body: dock.item?.hitItem ?? null
            readonly property point at: {
                if (!body) return Qt.point(0, 0)
                void (body.x + body.y + body.width + body.height + win.height)
                const p = body.mapToItem(win.contentItem, body.width, body.height / 2)
                return Qt.point(p.x, p.y)
            }
            x: Math.round(at.x + 10)
            y: Math.round(at.y - height / 2)
        }

        Loader {
            id: dock
            anchors.fill: parent
            sourceComponent: IrisDock { screen: win.screen }
        }
    }
}
}
