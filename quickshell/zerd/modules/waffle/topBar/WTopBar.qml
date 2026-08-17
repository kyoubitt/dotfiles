pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    Loader {
        id: loader
        required property var modelData

        readonly property var wBar: Config.options.waffles?.topBar ?? {}
        // Flat edge-to-edge bar, not a floating pill like the dock - no
        // margins, spans the full output width. Same thickness as the dock
        // (42) - a mismatch here is what broke the corner connecting to it,
        // no amount of color-matching fixes a geometry gap.
        readonly property int thickness: 42

        sourceComponent: PanelWindow {
            id: panelRoot
            screen: loader.modelData
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            // Distinct namespace from the other waffle panels so layer-shell
            // /niri window-rule matching by namespace doesn't collide.
            WlrLayershell.namespace: "quickshell:wTopBar"
            anchors { top: true; left: true; right: true }
            implicitHeight: loader.thickness
            exclusiveZone: loader.thickness
            visible: loader.wBar.enable ?? true

            WTopBarContent {
                anchors.fill: parent
                screen: panelRoot.screen
            }
        }
    }
}
