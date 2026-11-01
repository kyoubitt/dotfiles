pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Saved set-ups: a name, the wallpaper, the colour scheme and the main bar, dock and panel settings. Applying one
// puts all of it back at once. Kept in ~/.local/state/zerd-profiles.json.
Singleton {
    id: root

    // What a profile remembers besides the wallpaper.
    readonly property var keys: ["iris.appearance.scheme", "iris.wallust", "bars.top.autoHide", "bars.top.smartHide", "bars.top.showFocus",
        "bars.top.showTools", "bars.top.workspaceStyle", "bars.top.height", "bars.top.trayMax", "iris.dock.autoHide", "iris.dock.edge",
        "iris.dock.iconSize", "iris.dock.magnification", "bars.sidebars.edgeHover", "bars.sidebars.edgeSide", "bars.osd.enable", "bars.osd.position"]

    property var list: []
    property string active: ""

    function capture(name: string): void {
        const n = name.trim()
        if (n.length === 0) return
        const settings = {}
        for (const k of root.keys) { const v = Config.getNestedValue(k, undefined); if (v !== undefined) settings[k] = v }
        const p = { name: n, wallpaper: Config.options?.background?.wallpaperPath ?? "", settings: settings }
        root.list = root.list.filter(x => x.name !== n).concat([p])
        root.active = n
        root.save()
    }
    function apply(name: string): void {
        const p = root.list.find(x => x.name === name)
        if (!p) return
        for (const k of Object.keys(p.settings)) Config.setNestedValue(k, p.settings[k])
        if (p.wallpaper) WallpaperState.apply(p.wallpaper, "", 0.5, 0.5)
        root.active = name
        root.save()
    }
    function remove(name: string): void {
        root.list = root.list.filter(x => x.name !== name)
        if (root.active === name) root.active = ""
        root.save()
    }
    function save(): void { file.setText(JSON.stringify({ active: root.active, list: root.list })) }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/zerd-profiles.json"
        onLoaded: { try { const d = JSON.parse(file.text()); root.list = d.list ?? []; root.active = d.active ?? "" } catch (e) {} }
    }
}
