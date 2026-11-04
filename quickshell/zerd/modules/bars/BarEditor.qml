pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// Drag-and-drop editor for the top bar. The real bar stays on screen above; below it the blocks sit in
// Left / Middle / Right / Hidden boxes. Pick a block up, a gap opens where it will land, drop it. The
// small options (CPU, memory, weather ...) are switches underneath. Undo, redo and Reset to default.
Scope {
    id: root

    property bool open: false
    // Settings is closed while the editor is up, so the two never stack.
    onOpenChanged: if (open) GlobalStates.settingsOpen = false

    IpcHandler {
        target: "baredit"
        function open(): void { BarState.closeAll(); root.open = true }
        function close(): void { root.open = false }
        function toggle(): void { if (root.open) root.open = false; else { BarState.closeAll(); root.open = true } }
        function reset(): void { root.resetAll() }
        function undo(): void { root.undo() }
        function redo(): void { root.redo() }
    }

    readonly property var info: ({
        workspaces: { t: "Workspaces", i: "grid_view" },
        info: { t: "System and weather", i: "monitoring" },
        focus: { t: "Window title", i: "web_asset" },
        island: { t: "Clock and music", i: "schedule" },
        tools: { t: "Tools", i: "build" },
        keyboard: { t: "Keyboard layout", i: "keyboard" },
        status: { t: "Status icons", i: "tune" },
        tray: { t: "Tray", i: "apps" },
        end: { t: "Power", i: "power_settings_new" }
    })
    // Out of the box. Reset puts exactly this back.
    readonly property var defaults: ({
        left: ["workspaces", "info"], middle: ["island"],
        right: ["tools", "keyboard", "status", "tray", "end"], hidden: ["focus"]
    })
    readonly property var zones: [
        { key: "left", title: "Left" }, { key: "middle", title: "Middle" }, { key: "right", title: "Right" }, { key: "hidden", title: "Hidden" }
    ]
    readonly property var switches: [
        { k: "showCpu", t: "CPU", g: "System and weather" }, { k: "showMemory", t: "Memory", g: "System and weather" },
        { k: "showGpu", t: "GPU", g: "System and weather" }, { k: "showWeather", t: "Weather", g: "System and weather" },
        { k: "showBluetooth", t: "Bluetooth", g: "Status icons" }, { k: "showBattery", t: "Battery", g: "Status icons" }
    ]

    readonly property var top: Config.options?.bars?.top ?? ({})
    // What is in each box now; a block that is in none of them goes back to its default box.
    readonly property var layout: {
        const l = { left: [].concat(top.layoutLeft ?? []), middle: [].concat(top.layoutMiddle ?? []), right: [].concat(top.layoutRight ?? []), hidden: [].concat(top.layoutHidden ?? []) }
        const seen = {}
        for (const k in l) for (const id of l[k]) seen[id] = true
        for (const k in root.defaults) for (const id of root.defaults[k]) if (!seen[id]) l[k === "hidden" ? "right" : k].push(id)
        return l
    }
    function setLayout(l: var): void {
        const t = Config.options?.bars?.top
        if (!t) return
        t.layoutLeft = l.left; t.layoutMiddle = l.middle; t.layoutRight = l.right; t.layoutHidden = l.hidden
    }
    function setSwitch(k: string, on: bool): void { if (Config.options?.bars?.top) Config.options.bars.top[k] = on }

    // ---- history
    property var undoStack: []
    property var redoStack: []
    function snapshot(): var {
        const s = { layout: { left: root.layout.left.slice(), middle: root.layout.middle.slice(), right: root.layout.right.slice(), hidden: root.layout.hidden.slice() }, sw: {} }
        for (const d of root.switches) s.sw[d.k] = root.top[d.k] ?? true
        return s
    }
    function restore(s: var): void {
        root.setLayout(s.layout)
        for (const k in s.sw) root.setSwitch(k, s.sw[k])
    }
    function pushUndo(): void { root.undoStack = root.undoStack.concat([root.snapshot()]).slice(-60); root.redoStack = [] }
    function undo(): void {
        if (root.undoStack.length === 0) return
        const last = root.undoStack[root.undoStack.length - 1]
        root.redoStack = root.redoStack.concat([root.snapshot()])
        root.undoStack = root.undoStack.slice(0, -1)
        root.restore(last)
    }
    function redo(): void {
        if (root.redoStack.length === 0) return
        const next = root.redoStack[root.redoStack.length - 1]
        root.undoStack = root.undoStack.concat([root.snapshot()])
        root.redoStack = root.redoStack.slice(0, -1)
        root.restore(next)
    }
    function resetAll(): void {
        root.pushUndo()
        root.setLayout({ left: root.defaults.left.slice(), middle: root.defaults.middle.slice(), right: root.defaults.right.slice(), hidden: root.defaults.hidden.slice() })
        for (const d of root.switches) root.setSwitch(d.k, true)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            // the box layout while a block is held (the held block taken out), and where it will land
            property string dragId: ""
            property var preview: null
            property var insert: ({ zone: "", index: 0 })
            property real px: 0
            property real py: 0
            property real grabX: 0
            property real grabY: 0

            screen: modelData
            visible: root.open && !NiriService.inOverview
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            margins { top: 62 }
            WlrLayershell.namespace: "quickshell:zerd-bar-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            onVisibleChanged: if (!visible) { dragId = ""; preview = null }

            readonly property real cw: Math.min(1180, win.width - 96)
            readonly property real cx: Math.round((win.width - cw) / 2)
            readonly property real gap: 16
            readonly property real zw: Math.round((cw - 2 * gap) / 3)
            readonly property real zoneY: 92
            readonly property real rowH: 150
            readonly property real hiddenY: zoneY + rowH + gap
            readonly property real hiddenH: 124
            readonly property real optY: hiddenY + hiddenH + gap

            function zoneItems(key: string): var {
                const base = win.preview ? win.preview[key] : root.layout[key]
                if (win.dragId === "" || win.insert.zone !== key) return base
                const c = base.slice()
                c.splice(Math.min(win.insert.index, c.length), 0, "__gap__")
                return c
            }
            // Which chip is under the pointer: { zone, index, id } or null.
            function chipAt(x: real, y: real): var {
                for (let zi = 0; zi < zoneRep.count; zi++) {
                    const z = zoneRep.itemAt(zi)
                    if (!z) continue
                    for (let j = 0; j < z.chips.count; j++) {
                        const c = z.chips.itemAt(j)
                        if (!c) continue
                        const p = c.mapToItem(canvas, 0, 0)
                        if (x >= p.x && x <= p.x + c.width && y >= p.y && y <= p.y + c.height) return { zone: z.key, index: j, id: c.bid, ox: x - p.x, oy: y - p.y }
                    }
                }
                return null
            }
            function beginDrag(x: real, y: real): void {
                const hit = win.chipAt(x, y)
                if (!hit) return
                root.pushUndo()
                const p = { left: root.layout.left.slice(), middle: root.layout.middle.slice(), right: root.layout.right.slice(), hidden: root.layout.hidden.slice() }
                p[hit.zone].splice(hit.index, 1)
                win.preview = p
                win.grabX = hit.ox; win.grabY = hit.oy
                win.px = x; win.py = y
                win.insert = { zone: hit.zone, index: hit.index }
                win.dragId = hit.id
            }
            function moveDrag(x: real, y: real): void {
                if (win.dragId === "") return
                win.px = x; win.py = y
                let zone = ""
                for (let zi = 0; zi < zoneRep.count; zi++) {
                    const z = zoneRep.itemAt(zi)
                    if (z && x >= z.x - 8 && x <= z.x + z.width + 8 && y >= z.y - 8 && y <= z.y + z.height + 8) { zone = z.key; break }
                }
                if (zone === "") return
                const z = zoneRep.itemAt(root.zones.findIndex(q => q.key === zone))
                let idx = 0, n = 0, found = false
                for (let j = 0; j < z.chips.count; j++) {
                    const c = z.chips.itemAt(j)
                    if (!c || c.gap) continue
                    const p = c.mapToItem(canvas, 0, 0)
                    if (!found && (y < p.y + c.height && x < p.x + c.width / 2 || y < p.y)) { idx = n; found = true }
                    n++
                }
                if (!found) idx = n
                if (win.insert.zone !== zone || win.insert.index !== idx) win.insert = { zone: zone, index: idx }
            }
            function endDrag(): void {
                if (win.dragId === "") return
                const p = win.preview
                if (p && win.insert.zone !== "") {
                    const list = p[win.insert.zone].slice()
                    list.splice(Math.min(win.insert.index, list.length), 0, win.dragId)
                    p[win.insert.zone] = list
                    root.setLayout(p)
                }
                win.dragId = ""; win.preview = null
            }

            Item {
                id: canvas
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.open = false
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                        if (event.modifiers & Qt.ShiftModifier) root.redo(); else root.undo()
                        event.accepted = true
                    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) { root.redo(); event.accepted = true }
                }

                Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.01, 0.015, 0.82) }
                BarText { x: win.cx; y: 30; text: "Edit the bar"; font.pixelSize: 22; font.weight: Font.DemiBold; color: "white" }
                BarText { x: win.cx; y: 62; text: "Drag a block to another box, or along its box to change the order. The bar above follows when you let go."; font.pixelSize: 12; color: "#ffffffaa" }

                // the drag surface sits under the switches and the toolbar, over the boxes
                MouseArea {
                    anchors.fill: parent
                    cursorShape: win.dragId !== "" ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    onPressed: m => win.beginDrag(m.x, m.y)
                    onPositionChanged: m => win.moveDrag(m.x, m.y)
                    onReleased: win.endDrag()
                }

                Repeater {
                    id: zoneRep
                    model: root.zones
                    delegate: Rectangle {
                        id: zone
                        required property var modelData
                        required property int index
                        readonly property string key: modelData.key
                        readonly property bool target: win.dragId !== "" && win.insert.zone === key
                        property alias chips: chipRep
                        readonly property var items: win.zoneItems(key)
                        x: key === "hidden" ? win.cx : win.cx + index * (win.zw + win.gap)
                        y: key === "hidden" ? win.hiddenY : win.zoneY
                        width: key === "hidden" ? win.cw : win.zw
                        height: key === "hidden" ? win.hiddenH : win.rowH
                        radius: BarStyle.radiusLarge + 2
                        color: target ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        border.width: target ? 2 : 1
                        border.color: target ? BarStyle.accent : BarStyle.edge
                        Behavior on color { ColorAnimation { duration: 120 } }
                        BarText { x: 20; y: 14; text: modelData.title; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#ffffffaa" }
                        BarText {
                            visible: zone.items.length === 0
                            anchors.centerIn: parent
                            text: key === "hidden" ? "Nothing hidden. Drop a block here to hide it" : "Drop a block here"
                            font.pixelSize: 12; color: "#ffffff66"
                        }
                        Flow {
                            x: 14; y: 42; width: parent.width - 28; spacing: 8
                            Repeater {
                                id: chipRep
                                model: zone.items
                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property string bid: modelData
                                    readonly property bool gap: bid === "__gap__"
                                    height: 38; radius: 19
                                    width: gap ? 64 : chipRow.implicitWidth + 30
                                    color: gap ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.28) : (chipHover.hovered ? BarStyle.plateHover : BarStyle.surface)
                                    border.width: 1
                                    border.color: gap ? BarStyle.accent : Qt.rgba(1, 1, 1, 0.14)
                                    Behavior on color { ColorAnimation { duration: 90 } }
                                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Row {
                                        id: chipRow
                                        visible: !chip.gap
                                        anchors.centerIn: parent; spacing: 8
                                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: root.info[chip.bid]?.i ?? "widgets"; size: 18; color: BarStyle.accent }
                                        BarText { anchors.verticalCenter: parent.verticalCenter; text: root.info[chip.bid]?.t ?? chip.bid; font.pixelSize: 13 }
                                    }
                                    HoverHandler { id: chipHover; enabled: win.dragId === "" }
                                }
                            }
                        }
                    }
                }

                // the block in the hand
                Rectangle {
                    visible: win.dragId !== ""
                    x: win.px - win.grabX; y: win.py - win.grabY
                    height: 38; radius: 19; width: ghostRow.implicitWidth + 30
                    color: BarStyle.accent; scale: 1.06
                    z: 20
                    Rectangle { z: -1; anchors { fill: parent; topMargin: 6; leftMargin: -4; rightMargin: -4; bottomMargin: -10 } radius: 24; color: "#000000"; opacity: 0.28 }
                    Row {
                        id: ghostRow
                        anchors.centerIn: parent; spacing: 8
                        BarIcon { anchors.verticalCenter: parent.verticalCenter; name: root.info[win.dragId]?.i ?? "widgets"; size: 18; color: BarStyle.onAccent }
                        BarText { anchors.verticalCenter: parent.verticalCenter; text: root.info[win.dragId]?.t ?? ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: BarStyle.onAccent }
                    }
                }

                // switches for the small things inside a block
                Rectangle {
                    x: win.cx; y: win.optY; width: win.cw; height: 118; radius: BarStyle.radiusLarge + 2
                    color: Qt.rgba(1, 1, 1, 0.06); border.width: 1; border.color: BarStyle.edge
                    BarText { x: 20; y: 14; text: "Inside the blocks"; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#ffffffaa" }
                    Column {
                        x: 14; y: 40; spacing: 10
                        Repeater {
                            model: ["System and weather", "Status icons"]
                            delegate: Row {
                                id: swRow
                                required property string modelData
                                spacing: 8
                                BarText { width: 150; height: 32; verticalAlignment: Text.AlignVCenter; leftPadding: 6; text: swRow.modelData; font.pixelSize: 12; color: "#ffffffcc" }
                                Repeater {
                                    model: root.switches.filter(d => d.g === swRow.modelData)
                                    delegate: Rectangle {
                                        id: sw
                                        required property var modelData
                                        readonly property bool on: root.top[modelData.k] ?? true
                                        height: 32; radius: 16; width: swText.implicitWidth + 50
                                        color: on ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.24) : "transparent"
                                        border.width: 1; border.color: on ? BarStyle.accent : Qt.rgba(1, 1, 1, 0.18)
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: sw.on ? "check" : "close"; size: 14; color: sw.on ? BarStyle.accent : BarStyle.subtext }
                                        BarText { id: swText; x: 32; anchors.verticalCenter: parent.verticalCenter; text: sw.modelData.t; font.pixelSize: 12 }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.pushUndo(); root.setSwitch(sw.modelData.k, !sw.on) } }
                                    }
                                }
                            }
                        }
                    }
                }

                // undo, redo, reset, done
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 40
                    width: tools.implicitWidth + 28; height: 56; radius: 28
                    color: BarStyle.surface; border.width: 1; border.color: BarStyle.border
                    MouseArea { anchors.fill: parent }
                    Row {
                        id: tools
                        anchors.centerIn: parent; spacing: 8
                        Repeater {
                            model: [
                                { t: "Undo", i: "undo", a: "undo", off: root.undoStack.length === 0 },
                                { t: "Redo", i: "redo", a: "redo", off: root.redoStack.length === 0 },
                                { t: "Reset to default", i: "restart_alt", a: "reset", off: false },
                                { t: "Done", i: "", a: "done", off: false }
                            ]
                            delegate: Rectangle {
                                id: btn
                                required property var modelData
                                readonly property bool primary: modelData.a === "done"
                                height: 38; width: btnRow.implicitWidth + 26; radius: 19
                                opacity: modelData.off ? 0.4 : 1
                                color: primary ? BarStyle.accent : (bm.pressed ? BarStyle.border : "transparent")
                                border.width: primary ? 0 : 1; border.color: BarStyle.border
                                Row {
                                    id: btnRow
                                    anchors.centerIn: parent; spacing: 6
                                    BarIcon { visible: btn.modelData.i.length > 0; anchors.verticalCenter: parent.verticalCenter; name: btn.modelData.i; size: 16 }
                                    BarText { anchors.verticalCenter: parent.verticalCenter; text: btn.modelData.t; font.pixelSize: 12; font.weight: btn.primary ? Font.DemiBold : Font.Medium; color: btn.primary ? BarStyle.onAccent : BarStyle.text }
                                }
                                MouseArea {
                                    id: bm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (btn.modelData.a === "undo") root.undo()
                                        else if (btn.modelData.a === "redo") root.redo()
                                        else if (btn.modelData.a === "reset") root.resetAll()
                                        else root.open = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
