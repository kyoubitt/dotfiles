pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Every desktop card: its name in `Config.options.desktopWidgets`, a label, an icon and its size on screen.
Singleton {
    readonly property var cards: [
        { name: "media", cat: "Media", title: "Now playing", icon: "music_note", w: 380, h: 176 },
        { name: "clock", cat: "Clocks", title: "Clock", icon: "schedule", w: 176, h: 176 },
        { name: "cookieClock", cat: "Clocks", title: "Cookie clock", icon: "cookie", w: 200, h: 200 },
        { name: "pixelClock", cat: "Clocks", title: "Pixel clock", icon: "view_comfy", w: 240, h: 120 },
        { name: "stackedClock", cat: "Clocks", title: "Stacked clock", icon: "view_agenda", w: 200, h: 200 },
        { name: "weather", cat: "Info", title: "Weather", icon: "partly_cloudy_day", w: 176, h: 176 },
        { name: "wind", cat: "Info", title: "Wind", icon: "air", w: 176, h: 176 },
        { name: "rings", cat: "Info", title: "System rings", icon: "monitoring", w: 366, h: 176 },
        { name: "greeting", cat: "Fun", title: "Greeting", icon: "waving_hand", w: 380, h: 176 },
        { name: "calendar", cat: "Info", title: "Calendar", icon: "calendar_month", w: 360, h: 232 },
        { name: "agenda", cat: "Info", title: "Agenda", icon: "event_note", w: 380, h: 232 },
        { name: "lyrics", cat: "Media", title: "Lyrics", icon: "lyrics", w: 380, h: 226 },
        { name: "controls", cat: "Media", title: "Controls", icon: "tune", w: 380, h: 226 },
        { name: "date", cat: "Clocks", title: "Date", icon: "today", w: 176, h: 176 },
        { name: "day", cat: "Clocks", title: "Day", icon: "calendar_today", w: 176, h: 176 },
        { name: "battery", cat: "Info", title: "Battery", icon: "battery_full", w: 176, h: 176 },
        { name: "uptime", cat: "Info", title: "Uptime", icon: "timelapse", w: 176, h: 176 },
        { name: "worldClock", cat: "Clocks", title: "World clock", icon: "public", w: 380, h: 176 },
        { name: "todo", cat: "Tools", title: "To do", icon: "checklist", w: 300, h: 290 },
        { name: "notes", cat: "Tools", title: "Notes", icon: "edit_note", w: 300, h: 220 },
        { name: "timer", cat: "Tools", title: "Timer", icon: "timer", w: 380, h: 176 },
        { name: "visualizer", cat: "Media", title: "Visualizer", icon: "equalizer", w: 360, h: 120 },
        { name: "shape", cat: "Fun", title: "Shape", icon: "interests", w: 200, h: 200 }
    ]
    // Where each card sits out of the box (the same values as the settings defaults): what Reset puts back.
    readonly property var defaults: ({
        media: { anchor: "topLeft", mx: 80, my: 110 },
        clock: { anchor: "bottomLeft", mx: 80, my: 60 },
        weather: { anchor: "bottomLeft", mx: 264, my: 60 },
        rings: { anchor: "bottomRight", mx: 74, my: 252 },
        greeting: { anchor: "bottomRight", mx: 60, my: 60 },
        calendar: { anchor: "bottomLeft", mx: 80, my: 260 },
        wind: { anchor: "bottomLeft", mx: 264, my: 60 },
        agenda: { anchor: "topLeft", mx: 80, my: 320 },
        cookieClock: { anchor: "centerRight", mx: 120, my: -120 },
        pixelClock: { anchor: "centerRight", mx: 80, my: 120 },
        stackedClock: { anchor: "centerLeft", mx: 420, my: -120 },
        shape: { anchor: "centerLeft", mx: 420, my: 120 },
        visualizer: { anchor: "bottomLeft", mx: 500, my: 60 },
        controls: { anchor: "topRight", mx: 80, my: 110 },
        date: { anchor: "topRight", mx: 480, my: 110 },
        day: { anchor: "topRight", mx: 480, my: 310 },
        battery: { anchor: "topLeft", mx: 500, my: 110 },
        uptime: { anchor: "topLeft", mx: 500, my: 310 },
        worldClock: { anchor: "centerRight", mx: 480, my: 0 },
        todo: { anchor: "centerLeft", mx: 80, my: 0 },
        notes: { anchor: "centerLeft", mx: 420, my: 0 },
        lyrics: { anchor: "centerLeft", mx: 760, my: 0 },
        timer: { anchor: "centerRight", mx: 80, my: 0 }
    })
    // Size step of a card: 0.8, 1 or 1.25.
    function scaleOf(name: string): real {
        const l = Config.options?.desktopWidgets?.scales ?? []
        for (const e of l) {
            const i = String(e).lastIndexOf("|")
            if (String(e).slice(0, i) === name) return Number(String(e).slice(i + 1)) || 1
        }
        return 1
    }
    // Cards that grow by real size, not by magnifying (their text keeps its size and they show more instead).
    readonly property var sized: ["lyrics"]
    function visualScale(name: string): real { return sized.indexOf(name) >= 0 ? 1 : scaleOf(name) }
    function setScale(name: string, v: real): void {
        const t = Config.options?.desktopWidgets
        if (!t) return
        const next = [].concat(t.scales ?? []).filter(e => !String(e).startsWith(name + "|"))
        if (Math.abs(v - 1) > 0.01) next.push(name + "|" + v)
        t.scales = next
    }
    // Real sizes, reported by the live cards once they are loaded (the table above is only the first guess).
    property var measured: ({})
    function report(name: string, w: real, h: real): void {
        if (w <= 0 || h <= 0) return
        const m = measured[name]
        if (m && m.w === Math.round(w) && m.h === Math.round(h)) return
        const next = Object.assign({}, measured); next[name] = { w: Math.round(w), h: Math.round(h) }; measured = next
    }
    function sizeOf(name: string): var {
        const m = measured[name], c = of(name)
        return m ? { w: m.w, h: m.h } : { w: c.w, h: c.h }
    }
    function of(name: string): var { return cards.find(c => c.name === name) ?? { name: name, title: name, icon: "widgets", w: 200, h: 200 } }

    // Where a dragged card should land. `x`,`y` is the card's top-left corner under the pointer. With
    // `free` it stays exact. Otherwise it locks to the grid and is pulled (within `pull` px) onto the screen's
    // edges and centre lines and onto other cards' edges; `gx`/`gy` are the guide lines to draw (or -1).
    function snap(x: real, y: real, w: real, h: real, W: real, H: real, others: var, grid: int, lock: bool, free: bool): var {
        x = Math.max(0, Math.min(W - w, x)); y = Math.max(0, Math.min(H - h, y))
        if (free) return { x: Math.round(x), y: Math.round(y), gx: -1, gy: -1 }
        if (lock && grid > 0) { x = Math.round(x / grid) * grid; y = Math.round(y / grid) * grid }
        const pull = 10
        let gx = -1, gy = -1
        const xs = [{ at: 0, line: 0 }, { at: W - w, line: W }, { at: (W - w) / 2, line: W / 2 }]
        const ys = [{ at: 0, line: 0 }, { at: H - h, line: H }, { at: (H - h) / 2, line: H / 2 }]
        for (const o of others) {
            xs.push({ at: o.x, line: o.x }, { at: o.x + o.w - w, line: o.x + o.w }, { at: o.x + o.w, line: o.x + o.w }, { at: o.x - w, line: o.x })
            ys.push({ at: o.y, line: o.y }, { at: o.y + o.h - h, line: o.y + o.h }, { at: o.y + o.h, line: o.y + o.h }, { at: o.y - h, line: o.y })
        }
        let best = pull + 1
        for (const c of xs) { const d = Math.abs(c.at - x); if (d < best) { best = d; gx = c.line; x = c.at } }
        best = pull + 1
        for (const c of ys) { const d = Math.abs(c.at - y); if (d < best) { best = d; gy = c.line; y = c.at } }
        x = Math.max(0, Math.min(W - w, Math.round(x))); y = Math.max(0, Math.min(H - h, Math.round(y)))
        return { x: x, y: y, gx: gx, gy: gy }
    }
}
