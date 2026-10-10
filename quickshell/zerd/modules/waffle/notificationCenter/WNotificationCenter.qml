import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common

Scope {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.waffleNotificationCenterOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:notificationCenterBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.waffleNotificationCenterOpen = false
            }
        }
    }

    LazyLoader {
        active: GlobalStates.waffleNotificationCenterOpen
        component: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:notificationCenter"
            WlrLayershell.layer: WlrLayer.Overlay
            // See the clipboard panel's comment - Exclusive here was
            // silently killing the clipboard panel (or vice versa) whenever
            // both were open, since niri only allows one exclusive-focus
            // layer-shell surface at a time.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                right: true
            }
            margins {
                top: 20
                right: 20
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Connections {
                target: GlobalStates
                function onWaffleNotificationCenterOpenChanged() {
                    if (!GlobalStates.waffleNotificationCenterOpen) content.close()
                }
            }

            WNotificationCenterContent {
                id: content
                anchors.fill: parent
                onClosed: GlobalStates.waffleNotificationCenterOpen = false
                // OnDemand focus (see above) means nothing grabs keyboard
                // input just from opening - force it so Escape/Delete work
                // right away instead of needing a click first.
                Component.onCompleted: content.forceActiveFocus()
            }
        }
    }

    function toggleOpen() {
        GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen
    }

    IpcHandler {
        target: "notificationCenter"
        function toggle(): void { root.toggleOpen() }
        function open(): void { GlobalStates.waffleNotificationCenterOpen = true }
        function close(): void { GlobalStates.waffleNotificationCenterOpen = false }
    }
}
