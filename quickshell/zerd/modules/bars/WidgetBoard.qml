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
    // Writes a top-left position back as the nearest anchor plus margins.
    function place(name: string, x: real, y: real, W: real, H: real): void {
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
        DesktopWidgets.set(name, true)
        root.place(name, at.x, at.y, s.width, s.height)
    }
    function nudge(name: string, dx: int, dy: int): void {
        const s = Quickshell.screens[0], p = root.posOf(name, s.width, s.height)
        root.place(name, p.x + dx, p.y + dy, s.width, s.height)
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
        let x = Math.ceil(60 / g) * g, y = Math.ceil(110 / g) * g, rowH = 0
        for (const card of WidgetRegistry.cards) {
            if (!DesktopWidgets.enabled(card.name)) continue
            const sz = WidgetRegistry.sizeOf(card.name)
            if (x + sz.w > s.width - 60) { x = Math.ceil(60 / g) * g; y += Math.ceil((rowH + 16) / g) * g; rowH = 0 }
            root.place(card.name, x, y, s.width, s.height)
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
                    const step = (event.modifiers & Qt.ShiftModifier) ? Math.max(1, root.grid) : 1
                    if (win.selected === "") return
                    if (event.key === Qt.Key_Left) root.nudge(win.selected, -step, 0)
                    else if (event.key === Qt.Key_Right) root.nudge(win.selected, step, 0)
                    else if (event.key === Qt.Key_Up) root.nudge(win.selected, 0, -step)
                    else if (event.key === Qt.Key_Down) root.nudge(win.selected, 0, step)
                    else if (event.key === Qt.Key_Delete) { DesktopWidgets.set(win.selected, false); win.selected = "" }
                    else return
                    event.accepted = true
                }
                MouseArea { anchors.fill: parent; onClicked: { win.selected = ""; win.pickerOpen = false } }
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
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
            // Alignment guides while dragging.
            Rectangle { visible: win.guideX >= 0; x: win.guideX; y: 0; width: 1; height: parent.height; color: BarStyle.accent; opacity: 0.8 }
            Rectangle { visible: win.guideY >= 0; y: win.guideY; x: 0; height: 1; width: parent.width; color: BarStyle.accent; opacity: 0.8 }
            // Where the dragged card will land.
            Rectangle {
                visible: win.ghost !== null
                x: win.ghost?.x ?? 0; y: win.ghost?.y ?? 0; width: win.ghost?.w ?? 0; height: win.ghost?.h ?? 0
                radius: 22; color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.12)
                border.width: 2; border.color: BarStyle.accent
            }
            BarText { anchors.horizontalCenter: parent.horizontalCenter; y: 56; text: "Drag a card. It locks to the grid; hold Alt to place it freely. Arrows nudge, Delete removes."; color: "#ffffffbb"; font.pixelSize: 12 }

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
                    radius: 22
                    color: "transparent"
                    border.width: selected || dragging ? 2 : (dragHover.hovered ? 1 : 0)
                    border.color: overlaps ? BarStyle.danger : (selected || dragging ? BarStyle.accent : BarStyle.border)
                    opacity: dragging ? 0.8 : 1
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Binding on x { when: !frame.dragging; value: frame.target.x }
                    Binding on y { when: !frame.dragging; value: frame.target.y }
                    Behavior on x { enabled: !frame.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !frame.dragging; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    z: dragging ? 10 : (selected ? 5 : 1)

                    // The card itself, live; input is the board's, not the card's.
                    CardView {
                        id: live
                        name: frame.modelData.name
                        screenRef: win.screen
                        enabled: false
                        onLoaded: WidgetRegistry.report(frame.modelData.name, live.width, live.height)
                        onWidthChanged: WidgetRegistry.report(frame.modelData.name, live.width, live.height)
                        onHeightChanged: WidgetRegistry.report(frame.modelData.name, live.width, live.height)
                    }
                    HoverHandler { id: dragHover }
                    // Name tag on hover or selection.
                    Rectangle {
                        visible: frame.selected || dragHover.hovered
                        anchors { left: parent.left; bottom: parent.top; bottomMargin: 6 }
                        height: 24; width: tagText.implicitWidth + 18; radius: 12
                        color: BarStyle.surface; border.width: 1; border.color: BarStyle.border
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
                    Rectangle {
                        anchors { top: parent.top; right: parent.right; margins: 8 }
                        width: 26; height: 26; radius: 13
                        color: closeArea.pressed ? BarStyle.border : BarStyle.plateHover
                        BarIcon { anchors.centerIn: parent; name: "close"; size: 14 }
                        MouseArea { id: closeArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: DesktopWidgets.set(frame.modelData.name, false) }
                    }
                }
            }

            // ---- Add-widget picker: search + a vertical list grouped by kind.
            Rectangle {
                id: picker
                visible: opacity > 0
                opacity: win.pickerOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 110 } }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: toolbar.top
                anchors.bottomMargin: 12
                width: 360
                height: Math.min(460, win.height - 220)
                radius: 24
                color: BarStyle.surface
                border.width: 1; border.color: BarStyle.border
                MouseArea { anchors.fill: parent }
                Rectangle {
                    id: searchBox
                    x: 14; y: 14; width: parent.width - 28; height: 36; radius: 18
                    color: BarStyle.plateHover
                    border.width: 1; border.color: search.activeFocus ? BarStyle.accent : BarStyle.border
                    BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 16; color: BarStyle.subtext }
                    BarText { x: 36; anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "Search widgets"; color: BarStyle.subtext }
                    TextInput {
                        id: search
                        x: 36; width: parent.width - 48; height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: BarStyle.text; font.pixelSize: BarStyle.fontSize; clip: true
                        onVisibleChanged: if (visible && win.pickerOpen) forceActiveFocus(); else text = ""
                        Keys.onEscapePressed: win.pickerOpen = false
                    }
                }
                ListView {
                    id: list
                    x: 8; y: searchBox.y + searchBox.height + 8
                    width: parent.width - 16; height: parent.height - y - 10
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
                        BarText { x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: parent.section; font.pixelSize: 11; color: BarStyle.subtext }
                    }
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool added: DesktopWidgets.enabled(modelData.name)
                        width: list.width; height: 44; radius: 14
                        color: rowHover.hovered ? BarStyle.plateHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }
                        HoverHandler { id: rowHover }
                        BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: row.modelData.icon; size: 20; fill: 1; color: row.added ? BarStyle.accent : BarStyle.subtext }
                        BarText { x: 44; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.title; color: row.added ? BarStyle.subtext : BarStyle.text }
                        BarText { anchors.right: parent.right; anchors.rightMargin: 40; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.w + "×" + row.modelData.h; font.pixelSize: 11; color: BarStyle.subtext }
                        BarIcon { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: row.added ? "check_circle" : "add_circle"; size: 20; color: row.added ? BarStyle.accent : BarStyle.subtext }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (row.added) DesktopWidgets.set(row.modelData.name, false); else { root.add(row.modelData.name); win.selected = row.modelData.name } }
                        }
                    }
                }
            }

            // ---- Toolbar: add, grid size, auto grid lock, tidy, done.
            Rectangle {
                id: toolbar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                width: bar.implicitWidth + 28
                height: 56
                radius: 28
                color: BarStyle.surface
                border.width: 1; border.color: BarStyle.border
                MouseArea { anchors.fill: parent }
                component Pill: Rectangle {
                    id: pill
                    property string label
                    property string icon: ""
                    property bool on: false
                    property bool primary: false
                    signal tapped()
                    height: 38; width: pr.implicitWidth + 24; radius: 19
                    color: primary ? BarStyle.accent : (on ? Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.22) : (pm.pressed ? BarStyle.border : "transparent"))
                    border.width: primary ? 0 : 1
                    border.color: on ? BarStyle.accent : BarStyle.border
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Row {
                        id: pr
                        anchors.centerIn: parent; spacing: 6
                        BarIcon { visible: pill.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; name: pill.icon; size: 16; color: pill.primary ? BarStyle.onAccent : (pill.on ? BarStyle.accent : BarStyle.text) }
                        BarText { anchors.verticalCenter: parent.verticalCenter; text: pill.label; font.pixelSize: 12; font.weight: pill.primary ? Font.DemiBold : Font.Medium; color: pill.primary ? BarStyle.onAccent : (pill.on ? BarStyle.accent : BarStyle.text) }
                    }
                    MouseArea { id: pm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pill.tapped() }
                }
                Row {
                    id: bar
                    anchors.centerIn: parent
                    spacing: 8
                    Pill { icon: "add"; label: "Add widget"; on: win.pickerOpen; onTapped: win.pickerOpen = !win.pickerOpen }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: BarStyle.border }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: "Grid"; color: BarStyle.subtext; font.pixelSize: 12 }
                    Repeater {
                        model: [0, 8, 16, 32, 64]
                        delegate: Pill {
                            required property int modelData
                            label: modelData === 0 ? "Off" : String(modelData)
                            on: root.grid === modelData
                            onTapped: root.setBoard("grid", modelData)
                        }
                    }
                    Pill { icon: root.lock ? "grid_on" : "open_with"; label: root.lock ? "Snap" : "Free"; on: root.lock; onTapped: root.setBoard("snap", !root.lock) }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 24; color: BarStyle.border }
                    Pill { icon: "auto_fix_high"; label: "Tidy"; onTapped: root.tidy() }
                    Pill { label: "Done"; primary: true; onTapped: BarState.board = false }
                }
            }
        }
    }
}
