pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Small local event list for the calendar and agenda cards, kept in
// ~/.local/state/<shell>/user/events.json. Manage from a terminal:
//   qs -c zerd ipc call events add "Dentist" 2026-11-03 14:30   (time optional)
//   qs -c zerd ipc call events list
//   qs -c zerd ipc call events remove <id>
Singleton {
    id: root

    property var list: []

    FileView {
        id: file
        path: `${Directories.state}/user/events.json`
        onLoaded: {
            try { root.list = JSON.parse(file.text()) ?? [] } catch (e) { root.list = [] }
        }
        onLoadFailed: root.list = []
    }

    function _save(): void {
        file.setText(JSON.stringify(root.list, null, 1))
    }
    function _dateOf(ev: var): date { return new Date(ev.dateTime) }

    function add(title: string, day: string, time: string): string {
        const parts = day.split("-").map(Number)
        if (parts.length !== 3 || parts.some(isNaN)) return "bad date, use YYYY-MM-DD"
        const hm = (time || "").split(":").map(Number)
        const allDay = !time || hm.length < 2 || hm.some(isNaN)
        const when = new Date(parts[0], parts[1] - 1, parts[2], allDay ? 0 : hm[0], allDay ? 0 : hm[1])
        const id = Date.now()
        root.list = root.list.concat([{ id: id, title: title, dateTime: when.toISOString(), allDay: allDay }])
        _save()
        return String(id)
    }
    function remove(id: string): void {
        root.list = root.list.filter(e => String(e.id) !== String(id))
        _save()
    }

    function getEventsForDate(date: var): var {
        const d = new Date(date)
        return root.list.filter(ev => {
            const w = _dateOf(ev)
            return w.getFullYear() === d.getFullYear() && w.getMonth() === d.getMonth() && w.getDate() === d.getDate()
        })
    }
    function getUpcomingEvents(days: int): var {
        const start = new Date(); start.setHours(0, 0, 0, 0)
        const end = new Date(start.getTime() + days * 86400000)
        return root.list.filter(ev => { const w = _dateOf(ev); return w >= start && w < end })
            .sort((a, b) => _dateOf(a) - _dateOf(b))
    }

    IpcHandler {
        target: "events"
        function add(title: string, day: string, time: string): string { return root.add(title, day, time) }
        function remove(id: string): void { root.remove(id) }
        function list(): string {
            return root.list.map(e => `${e.id}  ${new Date(e.dateTime).toLocaleString()}  ${e.title}`).join("\n")
        }
    }
}
