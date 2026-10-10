pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

// Right-click menu for a dock app icon (Pin/Unpin, Close). Same
// separate-PanelWindow-flyout mechanism as WSideDockPinPicker, for the
// same reason: the dock's own PanelWindow is clipped to its thin strip, so
// nothing wider can render inside it. Kept as its own file rather than
// sharing plumbing with the picker - the two differ enough in how they're
// positioned (dock-edge-anchored vs. anchored at the exact clicked point)
// that a shared base would mostly be conditionals.
Scope {
    id: root

    LazyLoader {
        active: GlobalStates.dockContextMenuOpen && GlobalStates.dockContextMenuScreen !== null
        component: PanelWindow {
            screen: GlobalStates.dockContextMenuScreen
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wSideDockContextMenuBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: GlobalStates.dockContextMenuOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.dockContextMenuOpen && GlobalStates.dockContextMenuScreen !== null
        sourceComponent: PanelWindow {
            id: panelWindow
            screen: GlobalStates.dockContextMenuScreen
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wSideDockContextMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }

            readonly property int menuWidth: 176
            readonly property int edgeGap: 8

            // The anchor point comes from DockAppIcon's own
            // mapToItem(null, ...), which is relative to the *dock's own*
            // PanelWindow surface, not this screen's full desktop space.
            // That surface only spans the full screen along the dock's
            // long axis (e.g. full height for a vertical dock, since it's
            // anchored top+bottom) - along the short/thickness axis its
            // local origin is offset by wherever the dock's own edge sits
            // (0 if docked left/top, screen-thickness if docked
            // right/bottom), so that axis isn't usable as-is here. This
            // window covers the whole screen on every edge, so the
            // along-axis coordinate transfers directly; the thickness-axis
            // position is recomputed the same way WSideDockPinPicker does
            // it - anchored flush beside the dock's own edge - rather than
            // reused from the click.
            readonly property var wDock: Config.options.waffles?.sideDock ?? {}
            readonly property string edge: wDock.edge ?? "side"
            readonly property bool horizontal: edge === "top" || edge === "bottom"
            readonly property bool dockOnLeft: edge === "left"
            readonly property int thickness: wDock.thickness ?? 42

            readonly property real clampedX: panelWindow.horizontal
                ? Math.min(Math.max(GlobalStates.dockContextMenuAnchorX, edgeGap), Math.max(edgeGap, panelWindow.width - menuWidth - edgeGap))
                : (panelWindow.dockOnLeft ? panelWindow.thickness + edgeGap : panelWindow.width - panelWindow.thickness - edgeGap - menuWidth)
            readonly property real clampedY: panelWindow.horizontal
                ? (panelWindow.edge === "top" ? panelWindow.thickness + edgeGap : panelWindow.height - panelWindow.thickness - edgeGap - content.implicitHeight)
                : Math.min(Math.max(GlobalStates.dockContextMenuAnchorY, edgeGap), Math.max(edgeGap, panelWindow.height - content.implicitHeight - edgeGap))

            Connections {
                target: GlobalStates
                function onDockContextMenuOpenChanged() {
                    if (!GlobalStates.dockContextMenuOpen) content.close()
                }
            }

            WSideDockContextMenuContent {
                id: content
                x: panelWindow.clampedX
                y: panelWindow.clampedY
                width: panelWindow.menuWidth
                appId: GlobalStates.dockContextMenuAppId
                toplevels: GlobalStates.dockContextMenuToplevels
                focus: true
                onClosed: {
                    GlobalStates.dockContextMenuOpen = false
                    panelLoader.active = false
                }
            }
        }
    }
}
