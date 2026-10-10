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
        active: GlobalStates.waffleClipboardOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:clipboardBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.waffleClipboardOpen = false
            }
        }
    }

    LazyLoader {
        active: GlobalStates.waffleClipboardOpen
        component: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:clipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            // Exclusive would grab all keyboard input the instant this opens -
            // fine for a lone panel, but niri only lets one exclusive-focus
            // layer-shell surface exist at a time, so opening this while the
            // notification center was already open was silently killing that
            // one. OnDemand only grabs focus once something inside is
            // actually clicked, so both panels can be open together.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                right: true
            }
            // Both this panel and the notification center anchor top-right,
            // so when both are open at once, stack below it instead of the
            // two overlapping - GlobalStates.notificationCenterHeight is
            // reported live by WNotificationCenterContent's implicitHeight.
            margins {
                top: 20 + (GlobalStates.waffleNotificationCenterOpen ? GlobalStates.notificationCenterHeight + 16 : 0)
                right: 20
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Connections {
                target: GlobalStates
                function onWaffleClipboardOpenChanged() {
                    if (!GlobalStates.waffleClipboardOpen) content.close()
                }
            }

            WClipboardContent {
                id: content
                anchors.fill: parent
                onClosed: GlobalStates.waffleClipboardOpen = false
                // OnDemand focus (see above) means nothing grabs keyboard
                // input just from opening - force it onto the search box so
                // it's immediately typable (Escape still works, unhandled
                // key events bubble up to the root's Keys.onPressed).
                Component.onCompleted: content.focusSearch()
            }
        }
    }

    function toggleOpen() {
        GlobalStates.waffleClipboardOpen = !GlobalStates.waffleClipboardOpen
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggleOpen() }
        function open(): void { GlobalStates.waffleClipboardOpen = true }
        function close(): void { GlobalStates.waffleClipboardOpen = false }
    }
}
