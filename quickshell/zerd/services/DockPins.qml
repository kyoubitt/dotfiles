pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

// Pin state for the side dock's pinned-apps row, factored out of
// WSideDockContent.qml so the pin picker and context menu (separate
// top-level Scopes/PanelWindows, per the layer-shell constraints that force
// every dock overlay into its own surface) can read/mutate it without
// reaching into the dock's own root Item. Mirrors TrayService's existing
// pin()/unpin() shape.
Singleton {
    id: root

    readonly property var pinnedAppIds: (Config.options?.dock?.pinnedApps ?? []).map(id => id.toLowerCase())

    function isAppPinned(appId) {
        return root.pinnedAppIds.includes(appId.toLowerCase())
    }
    function pinApp(appId) {
        const pins = Config.options?.dock?.pinnedApps ?? []
        if (root.isAppPinned(appId)) return
        Config.setNestedValue("dock.pinnedApps", pins.concat([appId]))
    }
    function unpinApp(appId) {
        const pins = Config.options?.dock?.pinnedApps ?? []
        Config.setNestedValue("dock.pinnedApps", pins.filter(p => p.toLowerCase() !== appId.toLowerCase()))
    }
    function toggleAppPin(appId) {
        if (root.isAppPinned(appId)) root.unpinApp(appId)
        else root.pinApp(appId)
    }
}
