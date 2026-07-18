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

    Connections {
        target: GlobalStates
        function onSearchOpenChanged() {
            if (GlobalStates.searchOpen) panelLoader.active = true
        }
    }

    // Click-outside-to-close overlay
    LazyLoader {
        active: GlobalStates.searchOpen
        component: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "quickshell:wStartMenuBg"
            WlrLayershell.layer: WlrLayer.Top
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.searchOpen = false
            }
        }
    }

    Loader {
        id: panelLoader
        active: GlobalStates.searchOpen
        sourceComponent: PanelWindow {
            id: panelWindow
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wStartMenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            // Adaptive minimum size based on preset
            property string preset: Config.options.waffles?.startMenu?.sizePreset ?? "normal"
            property int minW: preset === "mini" ? 200 : preset === "compact" ? 280 : 360
            property int minH: preset === "mini" ? 200 : preset === "compact" ? 280 : 300

            // Anchored full-screen (invisible) so the visible card can be reliably
            // centered via centerIn below - anchoring just one edge leaves
            // positioning up to the compositor, which doesn't center it on niri.
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Connections {
                target: GlobalStates
                function onSearchOpenChanged() {
                    if (!GlobalStates.searchOpen) content.close()
                }
            }

            StartMenuContent {
                id: content
                anchors.centerIn: parent
                width: Math.max(panelWindow.minW, implicitWidth)
                height: Math.max(panelWindow.minH, implicitHeight)
                focus: true
                onClosed: {
                    GlobalStates.searchOpen = false
                    panelLoader.active = false
                    LauncherSearch.query = ""
                }
            }
        }
    }

    IpcHandler {
        target: "search"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
    }
}
