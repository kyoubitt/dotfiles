import qs.modules.onScreenKeyboard
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector

import qs.modules.waffle.actionCenter
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import qs.modules.common

Item {
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Waffle style (Windows 11)
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wStartMenu"; component: WaffleStartMenu {} }
    PanelLoader { identifier: "wActionCenter"; component: WaffleActionCenter {} }
    PanelLoader { identifier: "wNotificationCenter"; component: WaffleNotificationCenter {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }
    PanelLoader { identifier: "wWidgets"; extraCondition: Config.options?.waffles?.modules?.widgets ?? true; component: WaffleWidgets {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wPolkit"; component: Polkit {} }
    PanelLoader { identifier: "wSessionScreen"; component: SessionScreen {} }

    // Shared modules that work with waffle
    PanelLoader { identifier: "onScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "regionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "wallpaperSelector"; component: WallpaperSelector {} }

    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && Config.options?.panelFamily === "waffle"; component: WaffleClipboardModule.WaffleClipboard {} }

    // Waffle TaskView - experimental, disabled by default
    PanelLoader { identifier: "wTaskView"; component: WaffleTaskViewModule.WaffleTaskView {} }
}
