//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.closeConfirm
import qs.modules.customBar
import qs.modules.controlCenter
import qs.modules.mediaWidget
import qs.modules.soundWidget
import qs.modules.calendarWidget
import qs.modules.lockScreen

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

    // IPC for settings - open as separate window using execDetached
    IpcHandler {
        target: "settings"
        function open(): void {
            // -n = no daemon (standalone window), -p = path to QML file
            Quickshell.execDetached(["/usr/bin/qs", "-n", "-p", Quickshell.shellPath("waffleSettings.qml")])
        }
    }

    // === Panel Loaders ===
    LazyLoader {
        active: Config.ready
        component: ShellWafflePanels { }
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; component: CloseConfirm {} }

    // Custom bar - independent panel, not nested under waffle
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("customBar")
        component: WCustomBar {}
    }

    // Combined control center (toggles + media + notifications + calendar merged
    // into one panel) - independent panel, not nested under waffle
    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("controlCenter")
        component: WControlCenter {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("mediaWidget")
        component: WMediaWidget {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("soundWidget")
        component: WSoundWidget {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes("calendarWidget")
        component: WCalendarWidget {}
    }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // Native lock screen (WlSessionLock + PamContext) - always instantiated,
    // never behind a LazyLoader: the compositor leaves the screen
    // permanently blanked if this is destroyed while locked.
    LockScreen {}
}
