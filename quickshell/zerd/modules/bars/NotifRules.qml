pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Per-app notification rules, stored in `bars.notifications.rules` as "app|mode":
//   silent: no popup, still kept in the notification centre
//   mute:   no popup and dropped, it never reaches the centre
Singleton {
    readonly property var raw: Config.options?.bars?.notifications?.rules ?? []
    readonly property var map: {
        const m = {}
        for (const r of raw) {
            const i = String(r).lastIndexOf("|")
            if (i > 0) m[String(r).slice(0, i).toLowerCase()] = String(r).slice(i + 1)
        }
        return m
    }
    function modeOf(app: string): string { return map[String(app ?? "").toLowerCase()] ?? "normal" }
    function setMode(app: string, mode: string): void {
        const key = String(app ?? "").toLowerCase()
        const next = raw.filter(r => String(r).slice(0, String(r).lastIndexOf("|")).toLowerCase() !== key)
        if (mode !== "normal") next.push(app + "|" + mode)
        Config.options.bars.notifications.rules = next
    }
    function cycle(app: string): void {
        const m = modeOf(app)
        setMode(app, m === "normal" ? "silent" : m === "silent" ? "mute" : "normal")
    }
}
