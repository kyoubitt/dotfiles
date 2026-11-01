pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Stand-in for iNiR's floating-pieces registry. Apps are never detached from
// the dock here, so every query answers "not floating".
Singleton {
    function appPieceId(appId: string): string { return "app:" + String(appId ?? "").toLowerCase() }
    function appFloating(appId: string): bool { return false }
    function appIcon(appId: string, toplevels: var): string {
        const id = String(appId ?? "")
        // The game window's class is "Minecraft* <version>"; the shared icon
        // guess gives it the launcher's icon, so the dock uses the game's own.
        if (/^minecraft/i.test(id)) return Directories.assetsPath + "/icons/minecraft.png"
        // The shell's own windows (screenshot editor, settings) carry the class org.quickshell.
        // ...and Orbit, the music window, is told apart by its title.
        if (/^(org\.)?quickshell$/i.test(id)) {
            const titles = (toplevels ?? []).map(t => String(t?.title ?? ""))
            if (titles.length > 0 && titles.every(t => t === "Orbit")) return Directories.assetsPath + "/icons/orbit.svg"
            return Directories.assetsPath + "/icons/zerd.svg"
        }
        const entry = AppSearch.lookupDesktopEntry(id)
        return entry?.icon || AppSearch.guessIcon(id)
    }
    function labelOf(kind: string): string { return String(kind ?? "") }
    readonly property string defaultPlace: ""
    function placeApp(appId: string, place: string, x: real, y: real): void {}
    function removeApp(appId: string): void {}
}
