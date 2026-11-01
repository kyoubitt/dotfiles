pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool osdMediaOpen: false
    property string osdMediaAction: "play" // "play", "pause", "next", "previous"
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool altSwitcherOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    // Selection targets: "main", "backdrop", "waffle", "waffle-backdrop"
    property string wallpaperSelectionTarget: "main"
    onWallpaperSelectorOpenChanged: {
        // Reset selection target when selector closes without selection
        if (!wallpaperSelectorOpen) {
            wallpaperSelectionTarget = "main";
            // Also reset Config target if it was set
            if (Config.options?.wallpaperSelector?.selectionTarget && 
                Config.options.wallpaperSelector.selectionTarget !== "main") {
                Config.options.wallpaperSelector.selectionTarget = "main";
            }
        }
    }
    property bool cheatsheetOpen: false
    property bool workspaceShowNumbers: false
    property var activeTaskViewMenu: null  // Track which WindowThumbnail has its menu open
    // Waffle-specific states
    property bool searchOpen: false
    // Orbit (the music window) is opened from inside the shell, not by starting another process
    property int musicRequest: 0
    property bool waffleActionCenterOpen: false
    property bool waffleWidgetsOpen: false
    property bool waffleAltSwitcherOpen: false
    property bool waffleTaskViewOpen: false
    property bool controlCenterOpen: false
    property bool mediaWidgetOpen: false
    property bool soundWidgetOpen: false
    property bool calendarWidgetOpen: false
    property bool quickSettingsOpen: false
    property bool pinPickerOpen: false
    property var pinPickerScreen: null
    property bool dockContextMenuOpen: false
    property var dockContextMenuScreen: null
    property real dockContextMenuAnchorX: 0
    property real dockContextMenuAnchorY: 0
    property string dockContextMenuAppId: ""
    property var dockContextMenuToplevels: []

    // Close other waffle popups when one opens (unless allowMultiplePanels is enabled)
    property bool _allowMultiple: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false
    onSearchOpenChanged: {
        if (searchOpen && !_allowMultiple) {
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onWaffleActionCenterOpenChanged: {
        if (waffleActionCenterOpen && !_allowMultiple) {
            searchOpen = false
            waffleWidgetsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onWaffleWidgetsOpenChanged: {
        if (waffleWidgetsOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onWaffleTaskViewOpenChanged: {
        if (waffleTaskViewOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onPinPickerOpenChanged: {
        if (pinPickerOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            waffleTaskViewOpen = false
            controlCenterOpen = false
            mediaWidgetOpen = false
            soundWidgetOpen = false
            calendarWidgetOpen = false
            quickSettingsOpen = false
            dockContextMenuOpen = false
        }
    }
    onDockContextMenuOpenChanged: {
        if (dockContextMenuOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            waffleTaskViewOpen = false
            controlCenterOpen = false
            mediaWidgetOpen = false
            soundWidgetOpen = false
            calendarWidgetOpen = false
            quickSettingsOpen = false
            pinPickerOpen = false
        }
    }

    onControlCenterOpenChanged: {
        if (controlCenterOpen) {
            if (!_allowMultiple) {
                searchOpen = false
                waffleActionCenterOpen = false
                waffleWidgetsOpen = false
                mediaWidgetOpen = false
                soundWidgetOpen = false
                calendarWidgetOpen = false
                quickSettingsOpen = false
                pinPickerOpen = false
                dockContextMenuOpen = false
            }
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }
    onMediaWidgetOpenChanged: {
        if (mediaWidgetOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            controlCenterOpen = false
            soundWidgetOpen = false
            calendarWidgetOpen = false
            quickSettingsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onSoundWidgetOpenChanged: {
        if (soundWidgetOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            controlCenterOpen = false
            mediaWidgetOpen = false
            calendarWidgetOpen = false
            quickSettingsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onCalendarWidgetOpenChanged: {
        if (calendarWidgetOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            controlCenterOpen = false
            mediaWidgetOpen = false
            soundWidgetOpen = false
            quickSettingsOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }
    onQuickSettingsOpenChanged: {
        if (quickSettingsOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleWidgetsOpen = false
            controlCenterOpen = false
            mediaWidgetOpen = false
            soundWidgetOpen = false
            calendarWidgetOpen = false
            pinPickerOpen = false
            dockContextMenuOpen = false
        }
    }

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    property real screenZoom: 1
    onScreenZoomChanged: {
        // Niri doesn't have native zoom support like Hyprland's cursor:zoom_factor
        // The IPC handler still works but zoom is Hyprland-only for now
        if (!CompositorService.isHyprland)
            return;
        Quickshell.execDetached(["hyprctl", "keyword", "cursor:zoom_factor", root.screenZoom.toString()]);
    }
    Behavior on screenZoom {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "workspaceNumber"
            description: "Hold to show workspace numbers, release to show icons"

            onPressed: {
                root.superDown = true
            }
            onReleased: {
                root.superDown = false
            }
        }
    }

    IpcHandler {
		target: "zoom"

		function zoomIn(): void {
            screenZoom = Math.min(screenZoom + 0.4, 3.0)
        }

        function zoomOut(): void {
            screenZoom = Math.max(screenZoom - 0.4, 1)
        }
	}

    // Cycles the side dock's edge - WSideDock.qml already reads
    // waffles.sideDock.edge reactively and re-anchors itself, so this only
    // needs to write the next value through; no reload required.
    IpcHandler {
        target: "sideDock"

        function cycleEdge(): void {
            const order = ["left", "top", "side", "bottom"]
            const current = Config.options.waffles?.sideDock?.edge ?? "side"
            const next = order[(order.indexOf(current) + 1) % order.length]
            Config.setNestedValue("waffles.sideDock.edge", next)
        }

        function setEdge(edge: string): void {
            if (!["left", "side", "top", "bottom"].includes(edge)) {
                console.warn("[GlobalStates] sideDock setEdge: invalid edge", edge)
                return
            }
            Config.setNestedValue("waffles.sideDock.edge", edge)
        }
    }

    // For the vendored iRiS cards (modules/iris)
    property bool widgetEditMode: false

    // Floating dock (modules/iris/dock). The edit/bubble parts of the original
    // are not ported; these stay at their idle values so the dock reads them.
    property bool irisEdit: false
    property string irisEditTarget: ""
    property string irisEditSelection: ""
    property bool irisDockShown: false
    property var irisDockMenuRequest: null
    property var irisDockBody: ({})
    property var irisDockSlide: null
    property bool irisBubbleDrag: false
    property bool irisLauncherOpen: false
    property bool settingsOpen: false
    property bool focusMode: false             // DND, caffeine and night light on; bar and dock tucked away
    // Bar popup: { kind, x } or null. Opened by a bar item, drawn by BarPopupHost.
    property var barPopup: null
    property var irisAbsorbed: ({})
    property bool controlPanelOpen: false
    property string sidebarLeftPresentationOutput: ""
    property string sidebarRightPresentationOutput: ""
    function quietIrisLevels(): void {}
    property var focusedScreen: null
    property bool shellEntryReady: true
    function openSettings(): void {}
}
