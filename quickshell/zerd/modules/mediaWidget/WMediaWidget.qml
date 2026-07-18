import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common

Scope {
    id: root

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.mediaWidgetOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:mediaWidgetBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.mediaWidgetOpen = false
            }
        }
    }

    LazyLoader {
        active: GlobalStates.mediaWidgetOpen
        component: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:mediaWidget"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            // Anchored full-width (invisible) so content can be reliably
            // centered - anchoring just one edge doesn't center it on niri.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: content.implicitHeight + 44

            WMediaWidgetContent {
                id: content
                anchors {
                    top: parent.top
                    topMargin: 40
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    IpcHandler {
        target: "mediaWidget"
        function toggle(): void { GlobalStates.mediaWidgetOpen = !GlobalStates.mediaWidgetOpen }
        function open(): void { GlobalStates.mediaWidgetOpen = true }
        function close(): void { GlobalStates.mediaWidgetOpen = false }
    }
}
