import qs.modules.polkit
import qs.modules.wallpaperSelector
import qs.modules.sessionScreen

import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule

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
    PanelLoader { identifier: "wPolkit"; component: Polkit {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wSessionScreen"; component: SessionScreen {} }

    // Shared modules that work with waffle
    PanelLoader { identifier: "wallpaperSelector"; component: WallpaperSelector {} }
}
