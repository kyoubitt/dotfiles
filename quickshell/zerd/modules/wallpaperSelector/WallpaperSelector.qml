import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // Always active — keeps WallpaperSelectorContent alive so thumbnails
    // stay loaded in memory and Component.onCompleted only runs once.
    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(panelWindow.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (CompositorService.isNiri ? (panelWindow.screen?.name === NiriService.currentOutput) : true)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.wallpaperSelectorOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            // Only accept input when open — when closed the window is fully
            // transparent and pointer-invisible so it doesn't block the desktop.
            WlrLayershell.exclusiveZone: -1
            visible: GlobalStates.wallpaperSelectorOpen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Dim backdrop
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: GlobalStates.wallpaperSelectorOpen ? 0.7 : 0.0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: GlobalStates.wallpaperSelectorOpen
                    onClicked: GlobalStates.wallpaperSelectorOpen = false
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                opacity: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.0
                scale: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.97
                // Block all input when hidden
                enabled: GlobalStates.wallpaperSelectorOpen
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    enabled: GlobalStates.wallpaperSelectorOpen
                    onClicked: {}
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options?.wallpaperSelector?.useSystemFileDialog ?? false) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }

        if (Config.options?.panelFamily === "waffle") {
            const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
            Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
        } else {
            Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
        }

        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "wallpaperSelectorToggle"
                description: "Toggle wallpaper selector"
                onPressed: root.toggleWallpaperSelector()
            }

            GlobalShortcut {
                name: "wallpaperSelectorRandom"
                description: "Select random wallpaper in current folder"
                onPressed: Wallpapers.randomFromCurrentFolder()
            }
        }
    }
}
