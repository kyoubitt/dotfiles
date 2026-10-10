//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.closeConfirm
import qs.modules.controlCenter
import qs.modules.soundWidget
import qs.modules.mediaWidget
import qs.modules.lockScreen
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.sideDock as WaffleSideDockModule
import qs.modules.widgets as WidgetsModule
import qs.modules.waffle.startMenu
import qs.modules.polkit
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.notificationCenter as WaffleNotificationCenterModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.wallpaperSelector
import qs.modules.sessionScreen

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    function _log(msg: string): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(msg);
    }

    // Force singleton instantiation
    property var _idleService: Idle
    property var _gameModeService: GameMode
    property var _windowPreviewService: WindowPreviewService
    property var _weatherService: Weather
    property var _powerProfilePersistence: PowerProfilePersistence
    property var _voiceSearchService: VoiceSearch

    Component.onCompleted: {
        root._log("[Shell] Initializing singletons");
        Hyprsunset.load();
        FirstRunExperience.load();
        ConflictKiller.load();
    }

    // Default panel set for first run / corrupted config.
    readonly property list<string> defaultPanels: [
        "wBackground", "wStartMenu", "wPolkit", "wNotificationPopup", "wallpaperSelector"
    ]

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root._log("[Shell] Config ready, applying theme");
                Qt.callLater(() => ThemeService.applyCurrentTheme());
                Qt.callLater(() => IconThemeService.ensureInitialized());
                // Only reset enabledPanels if it's empty or undefined (first run / corrupted config)
                if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0) {
                    Config.options.enabledPanels = [...root.defaultPanels]
                }
            }
        }
    }

    // === Panel Loaders ===
    // Waffle background is enabled so overview/backdrop blur can render.
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wBackground")
        component: WaffleBackgroundModule.WaffleBackground {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wBackground")
        component: WaffleBackgroundModule.WaffleOverviewBackdrop {}
    }

    // Start menu (application launcher) - handles IPC target "search"
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wStartMenu")
        component: WaffleStartMenu {}
    }

    // Polkit authentication dialog
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wPolkit")
        component: Polkit {}
    }

    // Notification popups
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wNotificationPopup")
        component: WaffleNotificationPopupModule.WaffleNotificationPopup {}
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; component: CloseConfirm {} }

    // Vertical side dock: workspace indicator, media toggle, quick toggles,
    // settings/power. Gated on its own Config.options.waffles.sideDock.enable
    // rather than enabledPanels, so it doesn't need a config-file migration.
    LazyLoader {
        active: Config.ready && (Config.options.waffles?.sideDock?.enable ?? true)
        component: WaffleSideDockModule.WSideDock {}
    }

    // Clock/calendar/weather/media widgets panel - top-right corner,
    // wallust-themed. Its own always-loaded Variants (per-screen, like
    // WSideDock), gated on a config toggle that defaults on so it doesn't
    // need a config-file migration, matching the sideDock.enable pattern.
    LazyLoader {
        active: Config.ready && (Config.options.widgets?.enable ?? true)
        component: WidgetsModule.WWidgetsPanel {}
    }

    // Pin picker flyout for the side dock's pinned-apps row - kept as its
    // own always-loaded Scope (like CloseConfirm above) rather than nested
    // inside WSideDock, since it's a separate top-level Scope/PanelWindow,
    // not dock content. Gated only on GlobalStates.pinPickerOpen internally.
    LazyLoader {
        active: Config.ready && (Config.options.waffles?.sideDock?.enable ?? true)
        component: WaffleSideDockModule.WSideDockPinPicker {}
    }

    // Right-click context menu for a dock app icon - same reasoning as the
    // pin picker above.
    LazyLoader {
        active: Config.ready && (Config.options.waffles?.sideDock?.enable ?? true)
        component: WaffleSideDockModule.WSideDockContextMenu {}
    }

    // Combined control center (toggles + media + notifications + calendar merged
    // into one panel) - independent panel, not nested under waffle
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("controlCenter")
        component: WControlCenter {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("soundWidget")
        component: WSoundWidget {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("mediaWidget")
        component: WMediaWidget {}
    }

    // Clipboard history flyout (GlobalStates.waffleClipboardOpen), toggled
    // from the top bar or `qs ipc call clipboard toggle`.
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("clipboard")
        component: WaffleClipboardModule.WClipboard {}
    }

    // Notification center flyout (GlobalStates.waffleNotificationCenterOpen),
    // showing full notification history - not just active popups. Toggled
    // from the top bar clock or `qs ipc call notificationCenter toggle`.
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("notificationCenter")
        component: WaffleNotificationCenterModule.WNotificationCenter {}
    }

    // Wallpaper selector (toggle via IPC / keybind)
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wallpaperSelector")
        component: WallpaperSelector {}
    }

    // Session/power menu (toggle via IPC / keybind)
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wSessionScreen")
        component: SessionScreen {}
    }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // Native lock screen (WlSessionLock + PamContext) - always instantiated,
    // never behind a LazyLoader: the compositor leaves the screen
    // permanently blanked if this is destroyed while locked.
    LockScreen {}
}
