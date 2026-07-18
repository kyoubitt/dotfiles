import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    Component.onCompleted: Notifications.ensureInitialized()

    Connections {
        target: GlobalStates
        function onControlCenterOpenChanged() {
            if (GlobalStates.controlCenterOpen) panelLoader.active = true
        }
    }

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.controlCenterOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:controlCenterBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.controlCenterOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.controlCenterOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:controlCenter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            anchors {
                top: true
                right: true
            }

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            Connections {
                target: GlobalStates
                function onControlCenterOpenChanged() {
                    if (!GlobalStates.controlCenterOpen) content.close()
                }
            }

            WControlCenterContent {
                id: content
                anchors.fill: parent
                onClosed: {
                    GlobalStates.controlCenterOpen = false
                    panelLoader.active = false
                }
            }
        }
    }

    function toggleOpen() {
        GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen
    }

    IpcHandler {
        target: "controlCenter"
        function toggle(): void { root.toggleOpen() }
        function open(): void { GlobalStates.controlCenterOpen = true }
        function close(): void { GlobalStates.controlCenterOpen = false }
    }
}
