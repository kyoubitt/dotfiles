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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    centerIn: parent
                    verticalCenterOffset: 30
                }
                width: 1500
                height: 500
                // Pure fade when opening the wallpaper selector
                opacity: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options?.wallpaperSelector?.useSystemFileDialog ?? false) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        
        // Set target based on active family and config
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
                onPressed: {
                    root.toggleWallpaperSelector();
                }
            }

            GlobalShortcut {
                name: "wallpaperSelectorRandom"
                description: "Select random wallpaper in current folder"
                onPressed: {
                    Wallpapers.randomFromCurrentFolder();
                }
            }
        }
    }
}
