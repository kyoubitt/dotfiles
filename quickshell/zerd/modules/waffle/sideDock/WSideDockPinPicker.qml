pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common

// The dock's own PanelWindow is a real wlr-layer-shell surface clipped to
// its own thin strip (thickness, ~42px) on the cross-axis - nothing can
// render past that buffer. Every other waffle overlay (WaffleStartMenu,
// etc.) solves the same problem the same way: its own full-screen anchored
// PanelWindow (transparent, click-outside-to-close) plus a second
// PanelWindow for the actual content. This copies that pattern rather than
// trying to pop content out of the dock's own surface.
Scope {
    id: root

    LazyLoader {
        active: GlobalStates.pinPickerOpen && GlobalStates.pinPickerScreen !== null
        component: PanelWindow {
            screen: GlobalStates.pinPickerScreen
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wSideDockPinPickerBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.pinPickerOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.pinPickerOpen && GlobalStates.pinPickerScreen !== null
        sourceComponent: PanelWindow {
            id: panelWindow
            screen: GlobalStates.pinPickerScreen
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wSideDockPinPicker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            readonly property var wDock: Config.options.waffles?.sideDock ?? {}
            readonly property string edge: wDock.edge ?? "side"
            readonly property bool horizontal: edge === "top" || edge === "bottom"
            readonly property bool dockOnLeft: edge === "left"
            readonly property int thickness: wDock.thickness ?? 42
            // Gap between the dock's own edge and the picker, so it reads
            // as "next to the dock" rather than flush against it.
            readonly property int gap: 10

            anchors { top: true; bottom: true; left: true; right: true }

            Connections {
                target: GlobalStates
                function onPinPickerOpenChanged() {
                    if (!GlobalStates.pinPickerOpen) content.close()
                }
            }

            WSideDockPinPickerContent {
                id: content
                anchors {
                    // Lines up with the pinned pill, which is itself
                    // vertically/horizontally centered in the dock.
                    verticalCenter: !panelWindow.horizontal ? parent.verticalCenter : undefined
                    horizontalCenter: panelWindow.horizontal ? parent.horizontalCenter : undefined
                    left: (!panelWindow.horizontal && panelWindow.dockOnLeft) ? parent.left : undefined
                    right: (!panelWindow.horizontal && !panelWindow.dockOnLeft) ? parent.right : undefined
                    top: (panelWindow.horizontal && panelWindow.edge === "top") ? parent.top : undefined
                    bottom: (panelWindow.horizontal && panelWindow.edge !== "top") ? parent.bottom : undefined
                    leftMargin: (!panelWindow.horizontal && panelWindow.dockOnLeft) ? panelWindow.thickness + panelWindow.gap : 0
                    rightMargin: (!panelWindow.horizontal && !panelWindow.dockOnLeft) ? panelWindow.thickness + panelWindow.gap : 0
                    topMargin: (panelWindow.horizontal && panelWindow.edge === "top") ? panelWindow.thickness + panelWindow.gap : 0
                    bottomMargin: (panelWindow.horizontal && panelWindow.edge !== "top") ? panelWindow.thickness + panelWindow.gap : 0
                }
                focus: true
                onClosed: {
                    GlobalStates.pinPickerOpen = false
                    panelLoader.active = false
                }
            }
        }
    }
}
