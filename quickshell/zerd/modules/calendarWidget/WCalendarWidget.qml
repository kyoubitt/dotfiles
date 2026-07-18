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
        active: GlobalStates.calendarWidgetOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:calendarWidgetBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.calendarWidgetOpen = false
            }
        }
    }

    LazyLoader {
        active: GlobalStates.calendarWidgetOpen
        component: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:calendarWidget"
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

            WCalendarWidgetContent {
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
        target: "calendarWidget"
        function toggle(): void { GlobalStates.calendarWidgetOpen = !GlobalStates.calendarWidgetOpen }
        function open(): void { GlobalStates.calendarWidgetOpen = true }
        function close(): void { GlobalStates.calendarWidgetOpen = false }
    }
}
