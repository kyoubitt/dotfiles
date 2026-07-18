import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common

Scope {
    id: root

    LazyLoader {
        active: GlobalStates.barOpen
        component: PanelWindow {
            id: panelWindow
            exclusiveZone: 40
            WlrLayershell.namespace: "quickshell:customBar"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 40

            WCustomBarContent {
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "customBar"
        function toggle(): void { GlobalStates.barOpen = !GlobalStates.barOpen }
        function close(): void { GlobalStates.barOpen = false }
        function open(): void { GlobalStates.barOpen = true }
    }
}
