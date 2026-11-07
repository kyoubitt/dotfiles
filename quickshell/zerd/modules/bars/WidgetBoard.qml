pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.desktopWidgets

// Full-screen board for arranging the desktop cards: every enabled card shows as a frame at its real
// place and size, drag it anywhere, and the position is written back to the card's settings (a corner
// anchor plus margins), so the real card follows. Cards you have not added wait in the tray at the bottom.
Scope {
    id: root

    IpcHandler {
        target: "widgetboard"
        function toggle(): void { BarState.toggleBoard() }
        function open(): void { BarState.openBoard() }
        function close(): void { BarState.board = false }
        function add(name: string): void { root.add(name) }
        function remove(name: string): void { DesktopWidgets.set(name, false) }
        function tidy(): void { root.tidy() }
        function undo(): void { root.undo() }
        function redo(): void { root.redo() }
        function reset(): void { root.resetAll() }
    }

    function cfg(name: string): var { return Config.options?.desktopWidgets?.[name] ?? null }
    // Where a card sits (top-left corner) on a screen of this size, from its anchor and margins.
    function posOf(name: string, W: real, H: real): point {
        const c = root.cfg(name), card = WidgetRegistry.sizeOf(name)
        const a = c?.anchor ?? "topLeft"
        const x = a.endsWith("Right") ? W - card.w - (c?.mx ?? 0) : a.endsWith("Left") ? (c?.mx ?? 0) : (W - card.w) / 2
        const y = a.startsWith("bottom") ? H - card.h - (c?.my ?? 0) : a.startsWith("top") ? (c?.my ?? 0) : (H - card.h) / 2
        return Qt.point(Math.round(x), Math.round(y))
    }
    // ---- Undo / redo / reset: a snapshot of every card's switch and place is kept before each change.
    property var undoStack: []
    property var redoStack: []
    function snapshot(): var {
        const s = {}
        for (const card of WidgetRegistry.cards) {
            const c = root.cfg(card.name)
            if (c) s[card.name] = { enable: c.enable, anchor: c.anchor, mx: c.mx, my: c.my }
        }
        s["__scales"] = [].concat(Config.options?.desktopWidgets?.scales ?? [])
        return s
    }
    function pushUndo(): void { root.undoStack = root.undoStack.concat([root.snapshot()]).slice(-60); root.redoStack = [] }
    function restore(s: var): void {
        if (s["__scales"] && Config.options?.desktopWidgets) Config.options.desktopWidgets.scales = s["__scales"]
        for (const n in s) {
            if (n === "__scales") continue
            const c = root.cfg(n)
            if (!c) continue
            c.anchor = s[n].anchor; c.mx = s[n].mx; c.my = s[n].my
            DesktopWidgets.set(n, s[n].enable)
        }
    }
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
    // Every card back to where it sits out of the box (the switches stay as they are). Undo brings the old places back.
    function resetAll(): void {
        root.pushUndo()
        for (const card of WidgetRegistry.cards) {
            const d = WidgetRegistry.defaults[card.name], c = root.cfg(card.name)
            if (d && c) { c.anchor = d.anchor; c.mx = d.mx; c.my = d.my }
        }
        if (Config.options?.desktopWidgets) Config.options.desktopWidgets.scales = []
    }
    function setCardScale(name: string, v: real): void { root.pushUndo(); WidgetRegistry.setScale(name, v) }
    function removeCard(name: string): void { root.pushUndo(); DesktopWidgets.set(name, false) }
    // Lines a card up with the screen: left / centre / right, top / middle / bottom.
    function alignTo(name: string, mode: string, W: real, H: real): void {
        const p = root.posOf(name, W, H), sz = WidgetRegistry.sizeOf(name), m = 40
        let x = p.x, y = p.y
        if (mode === "left") x = m; else if (mode === "centre") x = (W - sz.w) / 2; else if (mode === "right") x = W - sz.w - m
        else if (mode === "top") y = m; else if (mode === "middle") y = (H - sz.h) / 2; else if (mode === "bottom") y = H - sz.h - m
        root.place(name, x, y, W, H)
    }
    Timer { id: nudgeTimer; interval: 700 }

    function place(name: string, x: real, y: real, W: real, H: real): void { root.pushUndo(); root.placeRaw(name, x, y, W, H) }
    // Writes a top-left position back as the nearest anchor plus margins.
    function placeRaw(name: string, x: real, y: real, W: real, H: real): void {
        const c = root.cfg(name), card = WidgetRegistry.sizeOf(name)
        if (!c) return
        x = Math.round(Math.max(0, Math.min(W - card.w, x)))
        y = Math.round(Math.max(0, Math.min(H - card.h, y)))
        const cx = x + card.w / 2, cy = y + card.h / 2
        const h = cx < W / 3 ? "Left" : cx > 2 * W / 3 ? "Right" : "Center"
        const v = cy < H / 3 ? "top" : cy > 2 * H / 3 ? "bottom" : "center"
        c.anchor = v + h
        c.mx = h === "Left" ? x : h === "Right" ? Math.round(W - x - card.w) : 0
        c.my = v === "top" ? y : v === "bottom" ? Math.round(H - y - card.h) : 0
    }
    readonly property var board: Config.options?.bars?.board ?? ({})
    readonly property int grid: board.grid ?? 32
    readonly property bool lock: board.snap ?? true
    readonly property bool showGrid: board.showGrid ?? true
    function setBoard(key: string, value: var): void { if (Config.options?.bars?.board) Config.options.bars.board[key] = value }
    function add(name: string): void {
        const c = root.cfg(name)
        if (!c) return
        const s = Quickshell.screens[0], card = WidgetRegistry.sizeOf(name)
        const at = WidgetRegistry.snap((s.width - card.w) / 2, (s.height - card.h) / 2, card.w, card.h, s.width, s.height, [], root.grid, root.lock, false)
        root.pushUndo()
        DesktopWidgets.set(name, true)
        root.placeRaw(name, at.x, at.y, s.width, s.height)
    }
    function nudge(name: string, dx: int, dy: int): void {
        const s = Quickshell.screens[0], p = root.posOf(name, s.width, s.height)
        if (!nudgeTimer.running) root.pushUndo()      // one undo step for a run of key presses
        nudgeTimer.restart()
        root.placeRaw(name, p.x + dx, p.y + dy, s.width, s.height)
    }
    // Rectangles of the other enabled cards, for snapping and overlap checks.
    function rects(except: string, W: real, H: real): var {
        const out = []
        for (const card of WidgetRegistry.cards) {
            if (card.name === except || !DesktopWidgets.enabled(card.name)) continue
            const p = root.posOf(card.name, W, H)
            const sz = WidgetRegistry.sizeOf(card.name)
            out.push({ x: p.x, y: p.y, w: sz.w, h: sz.h })
        }
        return out
    }
    // Nearest spot to (x, y) where the card overlaps no other: beside, above or below a neighbour.
    function freeSpot(x: real, y: real, w: real, h: real, others: var, W: real, H: real): point {
        const hit = (cx, cy) => others.some(o => cx < o.x + o.w && cx + w > o.x && cy < o.y + o.h && cy + h > o.y)
        if (!hit(x, y)) return Qt.point(x, y)
        let best = null, bestD = 1e18
        const gap = 8
        for (const o of others) {
            for (const c of [[o.x + o.w + gap, y], [o.x - w - gap, y], [x, o.y + o.h + gap], [x, o.y - h - gap]]) {
                const cx = Math.max(0, Math.min(W - w, c[0])), cy = Math.max(0, Math.min(H - h, c[1]))
                if (hit(cx, cy)) continue
                const d = (cx - x) * (cx - x) + (cy - y) * (cy - y)
                if (d < bestD) { bestD = d; best = Qt.point(cx, cy) }
            }
        }
        return best ?? Qt.point(x, y)
    }
    // Packs the enabled cards left to right, top to bottom.
    function tidy(): void {
        const s = Quickshell.screens[0]
        const g = Math.max(8, root.grid)
        root.pushUndo()
        let x = Math.ceil(60 / g) * g, y = Math.ceil(110 / g) * g, rowH = 0
        for (const card of WidgetRegistry.cards) {
            if (!DesktopWidgets.enabled(card.name)) continue
            const sz = WidgetRegistry.sizeOf(card.name)
            if (x + sz.w > s.width - 60) { x = Math.ceil(60 / g) * g; y += Math.ceil((rowH + 16) / g) * g; rowH = 0 }
            root.placeRaw(card.name, x, y, s.width, s.height)
            x += Math.ceil((sz.w + 16) / g) * g; rowH = Math.max(rowH, sz.h)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            property string selected: ""
            property bool pickerOpen: false
            property real guideX: -1
            property real guideY: -1
            property var ghost: null      // { x, y, w, h } where the dragged card will land
            property bool altDown: false

            screen: modelData
            visible: BarState.board && !NiriService.inOverview
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-widget-board"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            onVisibleChanged: if (!visible) { selected = ""; pickerOpen = false; ghost = null }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: { if (win.pickerOpen) win.pickerOpen = false; else BarState.board = false }
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                        if (event.modifiers & Qt.ShiftModifier) root.redo(); else root.undo()
                        event.accepted = true; return
                    }
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) { root.redo(); event.accepted = true; return }
                    const step = (event.modifiers & Qt.ShiftModifier) ? Math.max(1, root.grid) : 1
                    if (win.selected === "") return
                    if (event.key === Qt.Key_Left) root.nudge(win.selected, -step, 0)
                    else if (event.key === Qt.Key_Right) root.nudge(win.selected, step, 0)
                    else if (event.key === Qt.Key_Up) root.nudge(win.selected, 0, -step)
                    else if (event.key === Qt.Key_Down) root.nudge(win.selected, 0, step)
                    else if (event.key === Qt.Key_Delete) { root.removeCard(win.selected); win.selected = "" }
                    else return
                    event.accepted = true
                }
                MouseArea { anchors.fill: parent; onClicked: { win.selected = ""; win.pickerOpen = false } }
            }
            // Dark enough that the windows behind never compete with the cards being arranged.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.02, 0.01, 0.015, 0.88)
                opacity: BarState.board ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                enabled: false
            }
            // The grid: lines at the chosen size, drawn once per size.
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                visible: root.showGrid && root.grid > 0
                readonly property int step: root.grid
                onStepChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    if (step <= 0) return
                    // Small steps get a quieter line, with every fourth one stronger, so 8 px does not read as a mesh.
                    const quiet = step < 16
                    c.lineWidth = 1
                    for (let pass = 0; pass < (quiet ? 2 : 1); pass++) {
                        c.strokeStyle = pass === 0 ? (quiet ? "rgba(255,255,255,0.035)" : "rgba(255,255,255,0.07)") : "rgba(255,255,255,0.09)"
                        c.beginPath()
                        const every = pass === 0 ? 1 : 4
                        for (let x = 0, n = 0; x <= width; x += step, n++) if (n % every === 0) { c.moveTo(x + 0.5, 0); c.lineTo(x + 0.5, height) }
                        for (let y = 0, n = 0; y <= height; y += step, n++) if (n % every === 0) { c.moveTo(0, y + 0.5); c.lineTo(width, y + 0.5) }
                        c.stroke()
                    }
                }
            }
            // Snap guides: the four edges the dropped card will sit on, as faint lines through the whole screen, so
            // you can read which grid lines it locks to (and, in the stronger line below, what it lines up with).
            Rectangle { visible: win.ghost !== null && root.lock; x: (win.ghost?.x ?? 0); y: 0; width: 1; height: parent.height; color: BarStyle.accent; opacity: 0.3 }
            Rectangle { visible: win.ghost !== null && root.lock; x: (win.ghost?.x ?? 0) + (win.ghost?.w ?? 0) - 1; y: 0; width: 1; height: parent.height; color: BarStyle.accent; opacity: 0.3 }
            Rectangle { visible: win.ghost !== null && root.lock; y: (win.ghost?.y ?? 0); x: 0; height: 1; width: parent.width; color: BarStyle.accent; opacity: 0.3 }
            Rectangle { visible: win.ghost !== null && root.lock; y: (win.ghost?.y ?? 0) + (win.ghost?.h ?? 0) - 1; x: 0; height: 1; width: parent.width; color: BarStyle.accent; opacity: 0.3 }
            // Alignment guides while dragging: the screen's edges and middle, and the edges of the other cards.
            Rectangle { visible: win.guideX >= 0; x: win.guideX; y: 0; width: 1; height: parent.height; color: BarStyle.accent; opacity: 0.85 }
            Rectangle { visible: win.guideY >= 0; y: win.guideY; x: 0; height: 1; width: parent.width; color: BarStyle.accent; opacity: 0.85 }
            // Where the dragged card will land.
            Rectangle {
                visible: win.ghost !== null
                x: win.ghost?.x ?? 0; y: win.ghost?.y ?? 0; width: win.ghost?.w ?? 0; height: win.ghost?.h ?? 0
                radius: BarStyle.radiusLarge; color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.12)
                border.width: 2; border.color: BarStyle.accent
            }
            // Its place on the screen, over the corner of the ghost (under it when the card is at the top edge).
            Rectangle {
                visible: win.ghost !== null
                x: Math.max(8, Math.min(win.width - width - 8, win.ghost?.x ?? 0))
                y: (win.ghost?.y ?? 0) > 40 ? (win.ghost?.y ?? 0) - height - 8 : (win.ghost?.y ?? 0) + (win.ghost?.h ?? 0) + 8
                width: ghostText.implicitWidth + 20; height: 24; radius: 12
                color: BarStyle.surface; border.width: 1; border.color: BarStyle.edge
                BarText { id: ghostText; anchors.centerIn: parent; text: Math.round(win.ghost?.x ?? 0) + ", " + Math.round(win.ghost?.y ?? 0); font.pixelSize: 11; color: BarStyle.accent }
            }
            BarText { anchors.horizontalCenter: parent.horizontalCenter; y: 56; text: "Drag a card. It locks to the grid; hold Alt to place it freely. Arrows nudge, Delete removes."; color: BarStyle.subtext; font.pixelSize: 12 }

            Repeater {
                model: WidgetRegistry.cards.filter(c => DesktopWidgets.enabled(c.name))
                delegate: Rectangle {
                    id: frame
                    required property var modelData
                    readonly property point home: root.posOf(modelData.name, win.width, win.height)
                    // Where the frame rests. `home` is recomputed from three separate settings (anchor, mx, my), so it
                    // passes through wrong values while they are written; `target` only takes it once they settle.
                    property point target: Qt.point(0, 0)
                    onHomeChanged: settle.restart()
                    Component.onCompleted: target = home
                    Timer { id: settle; interval: 24; onTriggered: frame.target = frame.home }
                    readonly property bool selected: win.selected === modelData.name
                    property bool dragging: false
                    property real grabX: 0
                    property real grabY: 0
                    readonly property bool overlaps: {
                        for (const o of root.rects(modelData.name, win.width, win.height))
                            if (frame.x < o.x + o.w && frame.x + frame.width > o.x && frame.y < o.y + o.h && frame.y + frame.height > o.y) return true
                        return false
                    }
                    readonly property var size: WidgetRegistry.sizeOf(modelData.name)
                    width: size.w; height: size.h
                    radius: BarStyle.radiusLarge
                    color: "transparent"
                    border.width: selected || dragging ? 2 : (dragHover.hovered ? 1 : 0)
                    border.color: overlaps ? BarStyle.danger : (selected || dragging ? BarStyle.accent : BarStyle.border)
                    opacity: dragging ? 0.92 : 1
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    // Picked up: it lifts a little and its shadow grows; dropped: it springs into place.
                    scale: dragging ? 1.04 : 1
                    Behavior on scale { SpringAnimation { spring: 6; damping: 0.5; epsilon: 0.002 } }
                    Rectangle { z: -2; visible: frame.dragging; anchors { fill: parent; leftMargin: -10; rightMargin: -10; topMargin: -2; bottomMargin: -18 } radius: 32; color: "#000000"; opacity: 0.16 }
                    Rectangle { z: -1; visible: frame.dragging; anchors { fill: parent; leftMargin: -4; rightMargin: -4; topMargin: 2; bottomMargin: -10 } radius: 26; color: "#000000"; opacity: 0.22 }
                    Binding on x { when: !frame.dragging; value: frame.target.x }
                    Binding on y { when: !frame.dragging; value: frame.target.y }
                    Behavior on x { enabled: !frame.dragging; SpringAnimation { spring: 5; damping: 0.55; epsilon: 0.25 } }
                    Behavior on y { enabled: !frame.dragging; SpringAnimation { spring: 5; damping: 0.55; epsilon: 0.25 } }
                    z: dragging ? 10 : (selected ? 5 : 1)

                    // The card itself, live; input is the board's, not the card's.
                    CardView {
                        id: live
                        name: frame.modelData.name
                        screenRef: win.screen
                        enabled: false
                        readonly property real cs: WidgetRegistry.scaleOf(frame.modelData.name)
                        scale: cs
                        transformOrigin: Item.TopLeft
                        onCsChanged: WidgetRegistry.report(frame.modelData.name, live.width * cs, live.height * cs)
                        onLoaded: WidgetRegistry.report(frame.modelData.name, live.width * cs, live.height * cs)
                        onWidthChanged: WidgetRegistry.report(frame.modelData.name, live.width * cs, live.height * cs)
                        onHeightChanged: WidgetRegistry.report(frame.modelData.name, live.width * cs, live.height * cs)
                    }
                    HoverHandler { id: dragHover }
                    // Name tag on hover or selection.
                    Rectangle {
                        visible: frame.selected || dragHover.hovered
                        anchors { left: parent.left; bottom: parent.top; bottomMargin: 6 }
                        height: 26; width: tagText.implicitWidth + 20; radius: 13
                        color: BarStyle.surface; border.width: 1; border.color: BarStyle.edge
                        BarText { id: tagText; anchors.centerIn: parent; text: frame.modelData.title + (frame.selected ? "  ·  " + frame.width + " × " + frame.height : ""); font.pixelSize: 11 }
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        cursorShape: frame.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            win.selected = frame.modelData.name
                            win.pickerOpen = false
                            frame.grabX = mouse.x; frame.grabY = mouse.y
                            frame.dragging = true
                        }
                        onPositionChanged: mouse => {
                            if (!frame.dragging) return
                            const p = mapToItem(win.contentItem, mouse.x, mouse.y)
                            const rawX = p.x - frame.grabX, rawY = p.y - frame.grabY
                            // The card follows the pointer exactly; only the ghost is snapped.
                            frame.x = Math.max(0, Math.min(win.width - frame.width, rawX))
                            frame.y = Math.max(0, Math.min(win.height - frame.height, rawY))
                            const to = WidgetRegistry.snap(rawX, rawY, frame.width, frame.height, win.width, win.height,
                                root.rects(frame.modelData.name, win.width, win.height), root.grid, root.lock, (mouse.modifiers & Qt.AltModifier) !== 0)
                            win.ghost = { x: to.x, y: to.y, w: frame.width, h: frame.height }
                            win.guideX = to.gx; win.guideY = to.gy
                        }
                        onReleased: {
                            const g = win.ghost
                            // The frame glides to the ghost; the settings are written meanwhile, and `target` already
                            // holds the final spot so it never detours through the half-written values.
                            if (g) {
                                const f = root.freeSpot(g.x, g.y, g.w, g.h, root.rects(frame.modelData.name, win.width, win.height), win.width, win.height)
                                frame.target = f
                                root.place(frame.modelData.name, f.x, f.y, win.width, win.height)
                            }
                            frame.dragging = false
                            win.ghost = null; win.guideX = -1; win.guideY = -1
                        }
                    }
                    // size steps for the selected card
                    Row {
                        visible: frame.selected
                        anchors { left: parent.left; top: parent.bottom; topMargin: 10 }
                        spacing: 4
                        Repeater {
                            model: [{ l: "S", v: 0.8 }, { l: "M", v: 1 }, { l: "L", v: 1.25 }, { l: "XL", v: 1.5 }]
                            delegate: BarButton {
                                id: sz
                                required property var modelData
                                readonly property bool on: Math.abs(WidgetRegistry.scaleOf(frame.modelData.name) - modelData.v) < 0.01
                                width: sz.modelData.l.length > 1 ? 38 : 32; height: 28; radius: 14
                                tone: on ? "filled" : "outlined"
                                BarText { anchors.centerIn: parent; text: sz.modelData.l; font.pixelSize: 11; font.weight: Font.DemiBold; color: sz.ink }
                                onTapped: root.setCardScale(frame.modelData.name, sz.modelData.v)
                            }
                        }
                    }
                    // free resize: drag the corner, the card scales with it (0.6 to 1.8, in 5 % steps)
                    Rectangle {
                        id: grip
                        visible: frame.selected
                        anchors { right: parent.right; bottom: parent.bottom; margins: -6 }
                        width: 22; height: 22; radius: 11
                        color: BarStyle.accent; border.width: 2; border.color: BarStyle.surface
                        BarIcon { anchors.centerIn: parent; name: "open_in_full"; size: 12; color: BarStyle.onAccent }
                        property real startScale: 1
                        property real startW: 1
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.SizeFDiagCursor
                            onPressed: mouse => { root.pushUndo(); grip.startScale = WidgetRegistry.scaleOf(frame.modelData.name); grip.startW = Math.max(1, frame.width); win.selected = frame.modelData.name }
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                const dx = mapToItem(frame, mouse.x, mouse.y).x - frame.width
                                const k = Math.max(0.6, Math.min(1.8, grip.startScale * (grip.startW + dx) / grip.startW))
                                WidgetRegistry.setScale(frame.modelData.name, Math.round(k * 20) / 20)
                            }
                        }
                    }
                    BarButton {
                        id: closeBtn
                        anchors { top: parent.top; right: parent.right; margins: 8 }
                        width: 26; height: 26; radius: 13
                        BarIcon { anchors.centerIn: parent; name: "close"; size: 14; color: closeBtn.ink }
                        onTapped: root.removeCard(frame.modelData.name)
                    }
                }
            }

            // ---- Add-widget picker: search and a list grouped by kind. As tall as its list, and it sits on the tool strip.
            EditorPlate {
                id: picker
                visible: opacity > 0
                opacity: win.pickerOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 110 } }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: toolbar.top
                anchors.bottomMargin: 12
                width: 380
                title: "Add a widget"; icon: "widgets"
                hint: WidgetRegistry.cards.filter(c => DesktopWidgets.enabled(c.name)).length + " of " + WidgetRegistry.cards.length + " on the desktop"
                Rectangle {
                    id: searchBox
                    width: parent.width; height: 38; radius: 19
                    color: BarStyle.card
                    border.width: 1; border.color: search.activeFocus ? BarStyle.accent : BarStyle.edge
                    BarIcon { x: 13; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 17; color: BarStyle.subtext }
                    BarText { x: 38; anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "Search widgets"; color: BarStyle.subtext }
                    TextInput {
                        id: search
                        x: 38; width: parent.width - 66; height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                        selectionColor: BarStyle.accent; selectedTextColor: BarStyle.onAccent
                        onVisibleChanged: if (visible && win.pickerOpen) forceActiveFocus(); else text = ""
                        Keys.onEscapePressed: win.pickerOpen = false
                    }
                    BarIcon {
                        visible: search.text.length > 0
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        name: "close"; size: 16; color: BarStyle.subtext
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: search.text = "" }
                    }
                }
                ListView {
                    id: list
                    y: searchBox.height + 8
                    width: parent.width
                    height: Math.min(contentHeight, Math.max(140, Math.min(380, win.height - 380)))
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000
                    maximumFlickVelocity: 3000
                    spacing: 2
                    model: {
                        const q = search.text.trim().toLowerCase()
                        return WidgetRegistry.cards.filter(c => q.length === 0 || c.title.toLowerCase().includes(q) || c.cat.toLowerCase().includes(q))
                            .slice().sort((a, b) => a.cat.localeCompare(b.cat))
                    }
                    section.property: "cat"
                    section.criteria: ViewSection.FullString
                    section.delegate: Item {
                        required property string section
                        width: list.width; height: 28
                        BarText { x: 6; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; font.pixelSize: 11; font.weight: Font.DemiBold; color: BarStyle.subtext }
                    }
                    delegate: BarButton {
                        id: row
                        tone: "plain"
                        required property var modelData
                        readonly property bool added: DesktopWidgets.enabled(modelData.name)
                        width: list.width; height: 50; radius: BarStyle.radiusSmall
                        onTapped: { if (row.added) root.removeCard(row.modelData.name); else { root.add(row.modelData.name); win.selected = row.modelData.name } }
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 38; height: 38; radius: 12
                            color: row.added ? BarStyle.accentContainer : BarStyle.cardHigh
                            BarIcon { anchors.centerIn: parent; name: row.modelData.icon; size: 20; fill: 1; color: row.added ? BarStyle.accent : BarStyle.subtext }
                        }
                        Column {
                            x: 54; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 54 - 46
                            BarText { width: parent.width; elide: Text.ElideRight; text: row.modelData.title; color: BarStyle.text }
                            BarText { width: parent.width; elide: Text.ElideRight; text: row.modelData.w + " × " + row.modelData.h; font.pixelSize: 11; color: BarStyle.subtext }
                        }
                        BarIcon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: row.added ? "check_circle" : "add_circle"; size: 22; fill: row.added ? 1 : 0; color: row.added ? BarStyle.accent : BarStyle.subtext }
                    }
                }
                BarText { visible: list.count === 0; y: searchBox.height + 12; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No widget matches"; color: BarStyle.subtext; font.pixelSize: 12 }
            }

            // ---- Align: with a card selected, line it up with the screen.
            EditorPlate {
                id: alignBar
                pill: true; fitWidth: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: toolbar.top
                anchors.bottomMargin: 12
                visible: opacity > 0
                opacity: win.selected !== "" && !win.pickerOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 110 } }
                Row {
                    spacing: 2
                    Repeater {
                        model: [{ m: "left", i: "align_horizontal_left" }, { m: "centre", i: "align_horizontal_center" }, { m: "right", i: "align_horizontal_right" },
                                { m: "top", i: "align_vertical_top" }, { m: "middle", i: "align_vertical_center" }, { m: "bottom", i: "align_vertical_bottom" }]
                        delegate: BarButton {
                            id: al
                            required property var modelData
                            tone: "plain"
                            width: 36; height: 36; radius: 18
                            BarIcon { anchors.centerIn: parent; name: al.modelData.i; size: 18; color: al.ink }
                            onTapped: root.alignTo(win.selected, al.modelData.m, win.width, win.height)
                            BarTip { text: "Align " + al.modelData.m }
                        }
                    }
                }
            }

            // ---- Toolbar: add, grid size, snap, tidy, history, done.
            EditorPlate {
                id: toolbar
                pill: true; fitWidth: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                Row {
                    id: bar
                    spacing: 8
                    EditorChip { size: 40; icon: "add"; label: "Add widget"; toggled: win.pickerOpen; onTapped: win.pickerOpen = !win.pickerOpen }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: BarStyle.edge }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; color: BarStyle.subtext; font.pixelSize: 12 }
                    Repeater {
                        model: [0, 8, 16, 32, 64]
                        delegate: EditorChip {
                            required property int modelData
                            size: 40
                            label: modelData === 0 ? "Off" : String(modelData)
                            toggled: root.grid === modelData
                            onTapped: root.setBoard("grid", modelData)
                        }
                    }
                    EditorChip { size: 40; icon: root.lock ? "grid_on" : "open_with"; label: root.lock ? "Snap" : "Free"; toggled: root.lock; onTapped: root.setBoard("snap", !root.lock) }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: BarStyle.edge }
                    EditorChip { size: 40; icon: "auto_fix_high"; label: "Tidy"; onTapped: root.tidy() }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: BarStyle.edge }
                    EditorChip { size: 40; icon: "undo"; label: "Undo"; dim: root.undoStack.length === 0; onTapped: root.undo() }
                    EditorChip { size: 40; icon: "redo"; label: "Redo"; dim: root.redoStack.length === 0; onTapped: root.redo() }
                    EditorChip { size: 40; icon: "restart_alt"; label: "Reset"; onTapped: root.resetAll() }
                    EditorChip { size: 40; label: "Done"; primary: true; onTapped: BarState.board = false }
                }
            }
        }
    }
}
