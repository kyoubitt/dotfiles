//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.closeConfirm
import qs.modules.lockScreen
import qs.modules.bars as BarsModule
import qs.modules.music as MusicModule
import qs.modules.dock2 as Dock2Module
import qs.modules.iris.dock as IrisDockModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.sideDock as WaffleSideDockModule
import qs.modules.waffle.startMenu
import qs.modules.launcher as LauncherModule
import qs.modules.polkit
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
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
        MusicModule.Playback.ping();      // Orbit's player object exists from the start, so the bar can show its last song
    }

    // Default panel set for first run / corrupted config.
    readonly property list<string> defaultPanels: [
        "wBackground", "wStartMenu", "wPolkit", "wNotificationPopup"
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

    // Frees script garbage every few minutes, so the shell does not creep up in memory over a long session.
    Timer { interval: 300000; repeat: true; running: true; onTriggered: gc() }

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
        component: LauncherModule.LauncherHost {}
    }

    // Polkit authentication dialog
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wPolkit")
        component: Polkit {}
    }

    // Notification popups
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("wNotificationPopup") && (Config.options?.bars?.notifications?.engine ?? "rice") === "waffle"
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

    LazyLoader {
        active: Config.ready && ["macos", "pill", "panel"].includes(Config.options?.dock?.kind ?? "")
        component: Dock2Module.ClassicDock {}
    }

    // qs -c zerd ipc call dockkind set <iris|macos|pill|panel|off>
    IpcHandler {
        target: "dockkind"
        function set(kind: string): string {
            if (!["iris", "macos", "pill", "panel", "off"].includes(kind)) return "unknown kind"
            Config.setNestedValue(["dock", "kind"], kind)
            return kind
        }
        function get(): string { return Config.options?.dock?.kind ?? "iris" }
    }

    // Floating bars (modules/bars), each behind its own switch.
    // The music client (its window exists only while open).
    MusicModule.MusicWindow {}

    LazyLoader {
        active: Config.ready && (Config.options?.bars?.top?.enable ?? false)
        component: BarsModule.TopBar {}
    }
    LazyLoader {
        active: Config.ready && (Config.options?.bars?.side?.enable ?? false)
        component: BarsModule.SideBar {}
    }

    // Floating dock (modules/iris/dock), off until iris.dock.enable is set.
    // Independent of the side dock above.
    LazyLoader {
        active: Config.ready && (Config.options?.dock?.kind ?? "iris") === "iris" && (Config.options?.iris?.dock?.enable ?? false)
        component: IrisDockModule.IrisDockHost {}
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
