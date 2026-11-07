pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
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
    onOpenChanged: { BarState.editingBar = open; if (open) GlobalStates.settingsOpen = false }

    IpcHandler {
        target: "baredit"
        function open(): void { BarState.closeAll(); root.open = true }
        function close(): void { root.open = false }
        function toggle(): void { if (root.open) root.open = false; else { BarState.closeAll(); root.open = true } }
        function reset(): void { root.resetAll() }
        function undo(): void { root.undo() }
        function redo(): void { root.redo() }
        // the drag by hand (screen x, y), for testing without a pointer: press, move, release
        function press(x: int, y: int): void { root.win0()?.beginDrag(x, y) }
        function move(x: int, y: int): void { root.win0()?.moveDrag(x, y) }
        function release(): void { root.win0()?.endDrag() }
        function layout(): string { return JSON.stringify(root.layout) }
        function state(): string { return JSON.stringify({ open: root.open, overview: NiriService.inOverview, win: root.win0() ? root.win0().visible : null, editing: BarState.editingBar }) }
    }
    function win0(): var { return variants.instances[0] ?? null }

    readonly property var info: ({
        left: { t: "Menu", i: "menu" },
        workspaces: { t: "Workspaces", i: "grid_view" },
        media: { t: "Music", i: "music_note" },
        timedate: { t: "Clock and date", i: "schedule" },
        sysmon: { t: "System monitor", i: "monitoring" },
        weather: { t: "Weather", i: "partly_cloudy_day" },
        info: { t: "Indicators", i: "notifications" },
        tray: { t: "Tray", i: "apps" },
        kb: { t: "Keyboard layout", i: "keyboard" },
        wifi: { t: "Network", i: "wifi" },
        bt: { t: "Bluetooth", i: "bluetooth" },
        vol: { t: "Volume", i: "volume_up" },
        bat: { t: "Battery", i: "battery_full" },
        focus: { t: "Window title", i: "web_asset" }
    })
    // Out of the box. Reset puts exactly this back.
    readonly property var defaults: ({
        left: ["left", "workspaces", "media"], middle: ["timedate"],
        right: ["sysmon", "weather", "info", "tray", "kb", "wifi", "bt", "vol", "bat"], hidden: ["focus"]
    })
    readonly property var zones: [
        { key: "left", title: "Left" }, { key: "middle", title: "Middle" }, { key: "right", title: "Right" }, { key: "hidden", title: "Hidden" }
    ]
    readonly property var switches: []

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
    // one click: take a block off the bar (into Hidden) or put it back in its usual box
    function isHidden(id: string): bool { return root.layout.hidden.includes(id) }
    function toggleBlock(id: string): void {
        root.pushUndo()
        const l = { left: root.layout.left.filter(x => x !== id), middle: root.layout.middle.filter(x => x !== id), right: root.layout.right.filter(x => x !== id), hidden: root.layout.hidden.filter(x => x !== id) }
        if (!root.isHidden(id)) l.hidden.push(id)
        else {
            let to = "right"
            for (const k of ["left", "middle", "right"]) if (root.defaults[k].includes(id)) to = k
            l[to].push(id)
        }
        root.setLayout(l)
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
        id: variants
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            // what is held: its id, which box it came from, where the pointer is, and where it will land
            property string dragId: ""
            property string dragFrom: ""
            property var drop: ({ zone: "", index: 0 })
            property real px: 0
            property real py: 0
            property real grabX: 0
            property real grabY: 0
            property Item dragItem: null

            screen: modelData
            visible: root.open && !NiriService.inOverview
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-bar-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            onVisibleChanged: if (!visible) win.cancelDrag()

            // The bar, exactly as TopBar lays it out.
            readonly property string look: root.top.look ?? "pills"
            readonly property int barH: root.top.height ?? 34
            readonly property int margin: look === "strip" ? 0 : (root.top.margin ?? 8)
            readonly property int sidePad: look === "strip" ? 14 : (look === "floating" ? margin + 14 : margin)
            readonly property real areaH: barH + 2 * margin
            readonly property real cw: Math.min(1180, win.width - 96)
            readonly property real cx: Math.round((win.width - cw) / 2)
            // The boxes under the bar stack from here; the tool strip floats at the bottom.
            readonly property real stackY: areaH + 20
            readonly property real dockBottom: 40
            readonly property real dockH: 56

            function repOf(key: string): Repeater { return key === "left" ? leftRep : key === "middle" ? midRep : key === "right" ? rightRep : hiddenRep }
            function rowOf(key: string): Item { return key === "left" ? leftRow : key === "middle" ? midRow : key === "right" ? rightRow : hiddenFlow }
            function cancelDrag(): void {
                if (win.dragItem) win.dragItem.opacity = 1
                win.dragItem = null; win.dragId = ""; win.dragFrom = ""
            }
            function beginDrag(x: real, y: real): void {
                for (const z of root.zones) {
                    const rep = win.repOf(z.key), ids = root.layout[z.key]
                    for (let j = 0; j < rep.count; j++) {
                        const it = rep.itemAt(j)
                        if (!it || it.width < 2) continue
                        const p = it.mapToItem(canvas, 0, 0)
                        if (x >= p.x && x <= p.x + it.width && y >= p.y && y <= p.y + it.height) {
                            root.pushUndo()
                            win.dragItem = it; win.dragId = ids[j]; win.dragFrom = z.key
                            win.grabX = x - p.x; win.grabY = y - p.y
                            win.px = x; win.py = y
                            it.opacity = 0.25
                            win.drop = { zone: z.key, index: win.indexFor(z.key, x) }
                            return
                        }
                    }
                }
            }
            // Where in a box the held block would go: before the first block whose middle is right of the pointer.
            function indexFor(key: string, x: real): int {
                const rep = win.repOf(key), ids = root.layout[key]
                let n = 0
                for (let j = 0; j < rep.count; j++) {
                    if (ids[j] === win.dragId) continue
                    const it = rep.itemAt(j)
                    if (!it || it.width < 2) { n++; continue }
                    const p = it.mapToItem(canvas, 0, 0)
                    if (x < p.x + it.width / 2) return n
                    n++
                }
                return n
            }
            function moveDrag(x: real, y: real): void {
                if (win.dragId === "") return
                win.px = x; win.py = y
                let zone
                // the Hidden box sits wherever its content put it, so ask where it is now
                const hp = hiddenPlate.mapToItem(canvas, 0, 0)
                if (y > hp.y - 12 && y < hp.y + hiddenPlate.height + 12 && x > hp.x && x < hp.x + hiddenPlate.width) zone = "hidden"
                else if (y < win.areaH + 40) {
                    // the bar: the nearest of its three groups
                    let best = 1e9
                    for (const k of ["left", "middle", "right"]) {
                        const r = win.rowOf(k), c = r.x + (r.width > 0 ? r.width / 2 : 0)
                        const d = Math.abs(x - c)
                        if (d < best) { best = d; zone = k }
                    }
                } else return
                const idx = win.indexFor(zone, x)
                if (win.drop.zone !== zone || win.drop.index !== idx) win.drop = { zone: zone, index: idx }
            }
            function endDrag(): void {
                if (win.dragId === "") return
                const l = { left: root.layout.left.slice(), middle: root.layout.middle.slice(), right: root.layout.right.slice(), hidden: root.layout.hidden.slice() }
                const from = l[win.dragFrom].indexOf(win.dragId)
                if (from >= 0) l[win.dragFrom].splice(from, 1)
                if (win.drop.zone !== "") l[win.drop.zone].splice(Math.min(win.drop.index, l[win.drop.zone].length), 0, win.dragId)
                win.cancelDrag()
                root.setLayout(l)
            }
            // x of the marker that shows where the block will land
            function markerX(): real {
                if (win.drop.zone === "") return 0
                const key = win.drop.zone, rep = win.repOf(key), ids = root.layout[key]
                let n = 0, last = null
                for (let j = 0; j < rep.count; j++) {
                    if (ids[j] === win.dragId) continue
                    const it = rep.itemAt(j)
                    if (!it || it.width < 2) { n++; continue }
                    const p = it.mapToItem(canvas, 0, 0)
                    if (n === win.drop.index) return p.x - 5
                    last = { x: p.x + it.width + 5 }
                    n++
                }
                if (last) return last.x
                const r = win.rowOf(key).mapToItem(canvas, 0, 0)
                return r.x
            }
            function markerY(): real {
                if (win.drop.zone === "") return 0
                const r = win.rowOf(win.drop.zone).mapToItem(canvas, 0, 0)
                return r.y - 2
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

                // Nearly opaque: whatever window is behind never shows through the editor.
                Rectangle { anchors.fill: parent; color: Qt.rgba(0.02, 0.01, 0.015, 0.94) }

                // ---- the bar as it will look; its blocks are the real ones, only the clicks are the editor's
                Item {
                    id: barArea
                    x: 0; y: 0; width: win.width; height: win.areaH
                    enabled: false
                    Rectangle {
                        visible: win.look !== "pills"
                        x: win.look === "strip" ? 0 : win.margin
                        y: win.look === "strip" ? 0 : win.margin
                        width: parent.width - 2 * x; height: win.barH
                        radius: win.look === "strip" ? 0 : height / 2
                        color: BarStyle.plate
                        border.width: win.look === "floating" ? 1 : 0
                        border.color: BarStyle.border
                    }
                    Row {
                        id: leftRow
                        x: win.sidePad; anchors.verticalCenter: parent.verticalCenter
                        spacing: BarStyle.gap
                        Repeater { id: leftRep; model: root.layout.left; delegate: chooser }
                    }
                    Row {
                        id: midRow
                        x: Math.max(leftRow.x + leftRow.width + 12, Math.min(Math.round((parent.width - width) / 2), rightRow.x - width - 12))
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: BarStyle.gap
                        Repeater { id: midRep; model: root.layout.middle; delegate: chooser }
                    }
                    Row {
                        id: rightRow
                        x: parent.width - width - win.sidePad; anchors.verticalCenter: parent.verticalCenter
                        spacing: BarStyle.gap
                        Repeater { id: rightRep; model: root.layout.right; delegate: chooser }
                    }
                }
                Component {
                    id: chooser
                    BarBlock {
                        required property string modelData
                        blockId: modelData
                        barHeight: win.barH
                        screen: win.modelData
                        flat: win.look !== "pills"
                    }
                }
                // empty groups still get a place to drop
                Repeater {
                    model: ["left", "middle", "right"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool empty: root.layout[modelData].length === 0
                        visible: empty
                        x: modelData === "left" ? win.sidePad : modelData === "right" ? win.width - width - win.sidePad : Math.round((win.width - width) / 2)
                        y: Math.round((win.areaH - height) / 2)
                        width: 120; height: win.barH - 6; radius: height / 2
                        color: "transparent"; border.width: 1; border.color: BarStyle.subtext
                        BarText { anchors.centerIn: parent; text: modelData; font.pixelSize: 11; color: BarStyle.subtext }
                    }
                }

                // the drag surface: the whole screen, under the boxes and the tool strip (their own controls come first)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: win.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: m => win.beginDrag(m.x, m.y)
                    onPositionChanged: m => win.moveDrag(m.x, m.y)
                    onReleased: win.endDrag()
                }

                // ---- the boxes under the bar, stacked: each one is as tall as what is in it, so a wrapped row of
                // blocks pushes the next box down instead of running into it. Scrolls on a screen too short for all.
                Flickable {
                    id: stackView
                    x: win.cx; y: win.stackY
                    width: win.cw
                    height: Math.max(0, canvas.height - win.stackY - win.dockH - win.dockBottom - 24)
                    contentWidth: width
                    contentHeight: stack.height
                    clip: true
                    interactive: contentHeight > height && win.dragId === ""
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: stack
                        width: stackView.width
                        spacing: 12

                        BarText {
                            width: parent.width
                            text: "Drag a block in the bar above to move it, or down into Hidden to take it off the bar."
                            font.pixelSize: 13; color: BarStyle.subtext
                            wrapMode: Text.Wrap
                        }

                        // hidden blocks: a drop zone; a tap puts a block back, a drag moves it onto the bar
                        EditorPlate {
                            id: hiddenPlate
                            width: parent.width
                            title: "Hidden"; icon: "visibility_off"
                            hint: root.layout.hidden.length > 0 ? "tap a block to put it back" : ""
                            target: win.dragId !== "" && win.drop.zone === "hidden"
                            swallow: false
                            Item {
                                width: parent.width
                                height: Math.max(34, hiddenFlow.implicitHeight)
                                BarText { visible: root.layout.hidden.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "Nothing hidden. Drop a block here to hide it"; font.pixelSize: 12; color: BarStyle.subtext }
                                Flow {
                                    id: hiddenFlow
                                    width: parent.width; spacing: 8
                                    Repeater {
                                        id: hiddenRep
                                        model: root.layout.hidden
                                        delegate: Rectangle {
                                            id: hc
                                            required property string modelData
                                            height: 34; radius: 17; width: hcRow.implicitWidth + 26
                                            color: hcHover.hovered ? BarStyle.cardHover : BarStyle.card
                                            border.width: 1; border.color: BarStyle.edge
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                            HoverHandler { id: hcHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: root.toggleBlock(hc.modelData) }
                                            Row {
                                                id: hcRow
                                                x: 12; height: parent.height; spacing: 7
                                                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: root.info[hc.modelData]?.i ?? "widgets"; size: 16; color: BarStyle.accent }
                                                BarText { anchors.verticalCenter: parent.verticalCenter; text: root.info[hc.modelData]?.t ?? hc.modelData; font.pixelSize: 13 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // one click on a block: off the bar (into Hidden) or back where it belongs
                        EditorPlate {
                            width: parent.width
                            title: "On the bar"; icon: "visibility"
                            hint: "click a block to hide or show it"
                            Flow {
                                width: parent.width; spacing: 8
                                Repeater {
                                    model: Object.keys(root.info)
                                    delegate: EditorChip {
                                        id: bb
                                        required property string modelData
                                        readonly property bool off: root.isHidden(modelData)
                                        toggled: !off
                                        icon: off ? "visibility_off" : "visibility"
                                        label: root.info[modelData].t
                                        onTapped: root.toggleBlock(bb.modelData)
                                    }
                                }
                            }
                        }

                        // the small things inside a block
                        EditorPlate {
                            visible: root.switches.length > 0
                            width: parent.width
                            title: "Inside the blocks"; icon: "tune"
                            Column {
                                width: parent.width
                                spacing: 10
                                Repeater {
                                    model: ["System and weather", "Status icons"]
                                    delegate: Row {
                                        id: swRow
                                        required property string modelData
                                        width: parent.width
                                        spacing: 12
                                        BarText { width: 150; height: 34; verticalAlignment: Text.AlignVCenter; text: swRow.modelData; font.pixelSize: 12; color: BarStyle.subtext }
                                        Flow {
                                            width: swRow.width - 150 - swRow.spacing
                                            spacing: 8
                                            Repeater {
                                                model: root.switches.filter(d => d.g === swRow.modelData)
                                                delegate: EditorChip {
                                                    id: sw
                                                    required property var modelData
                                                    readonly property bool on: root.top[modelData.k] ?? true
                                                    toggled: on
                                                    icon: on ? "check" : "close"
                                                    label: modelData.t
                                                    onTapped: { root.pushUndo(); root.setSwitch(sw.modelData.k, !sw.on) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // where it will land
                Rectangle {
                    visible: win.dragId !== "" && win.drop.zone !== "hidden"
                    x: win.markerX(); y: win.markerY(); width: 3; height: win.barH + 4; radius: 2
                    color: BarStyle.accent
                }
                // the block in the hand: a live copy of it
                ShaderEffectSource {
                    visible: win.dragItem !== null
                    sourceItem: win.dragItem
                    live: true
                    x: win.px - win.grabX; y: win.py - win.grabY
                    width: win.dragItem ? win.dragItem.width : 0; height: win.dragItem ? win.dragItem.height : 0
                    scale: 1.05; z: 20
                }

                // undo, redo, reset, done
                EditorPlate {
                    pill: true; fitWidth: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: win.dockBottom
                    Row {
                        spacing: 8
                        Repeater {
                            model: [
                                { t: "Undo", i: "undo", a: "undo", off: root.undoStack.length === 0 },
                                { t: "Redo", i: "redo", a: "redo", off: root.redoStack.length === 0 },
                                { t: "Reset to default", i: "restart_alt", a: "reset", off: false },
                                { t: "Done", i: "", a: "done", off: false }
                            ]
                            delegate: EditorChip {
                                id: btn
                                required property var modelData
                                size: 40
                                primary: modelData.a === "done"
                                icon: modelData.i
                                iconSize: 18
                                label: modelData.t
                                dim: modelData.off
                                onTapped: {
                                    if (modelData.a === "undo") root.undo()
                                    else if (modelData.a === "redo") root.redo()
                                    else if (modelData.a === "reset") root.resetAll()
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
