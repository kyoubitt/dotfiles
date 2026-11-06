pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One overlay for taking and marking up a screenshot, like Spectacle. The screen is frozen, you drag the
// area (Region) or take the lot (Screen), and the tools appear right under the selection: draw on it,
// then Save or Copy, all in the same place. Window mode lists the windows and opens the editor window.
// Dragging works like slurp: every drag makes a new box (Space while dragging carries it along); the edges and corners resize it.
// Keys: Space or Enter copy, Ctrl+S save, 1 region, 2 window, 3 screen, S select, B I Z R E T M U G tools, Ctrl+Z/Y, Esc cancel.
// `ipc call screenshot open|region|window|screen|edit <png>|take <mode> <action>`.
Scope {
    id: root

    property bool open: false
    property string mode: "region"     // region | window | screen
    property int delay: 0              // seconds before the screen is frozen
    property bool cursor: false
    property string outName: ""
    property bool busy: false
    property bool exporting: false
    // For scripts: `screenshot take <mode> <action>` goes straight through without the tools.
    property string pending: ""
    property var pendingRect: null

    // The region (in the screen's own pixels as drawn) and the chosen window.
    property rect sel: Qt.rect(0, 0, 0, 0)    // one value, so a pointer move updates everything once
    readonly property real selX: sel.x
    readonly property real selY: sel.y
    readonly property real selW: sel.width
    readonly property real selH: sel.height
    property int windowId: -1
    property var scene: null           // the frozen screen with its marks, set by the visible overlay

    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    property int seq: 0
    readonly property string frozen: runtime + "/zerd-shot-frozen-" + seq + ".ppm"
    readonly property bool hasRegion: root.selW > 8 && root.selH > 8
    // A region with nothing dragged is the whole screen.
    readonly property bool ready: root.mode === "window" ? root.windowId >= 0 : true
    readonly property var screenObj: Quickshell.screens.find(s => s.name === root.outName) ?? Quickshell.screens[0]

    function begin(mode: string): void {
        if (root.open || root.busy) { if (root.open) root.setMode(mode); return }
        if (GlobalStates.screenLocked) return
        BarState.closeAll()
        // The launcher holds the keyboard exclusively; with it open the overlay never sees Space.
        GlobalStates.irisLauncherOpen = false
        GlobalStates.searchOpen = false            // the Waffle app menu holds the keyboard too
        GlobalStates.sessionOpen = false
        BarState.closeOverlays()                  // wallpaper picker, switcher: anything else that holds the keyboard
        GlobalStates.pinPickerOpen = false
        GlobalStates.dockContextMenuOpen = false
        GlobalStates.waffleActionCenterOpen = false
        GlobalStates.waffleWidgetsOpen = false
        if (!root.pendingRect) root.sel = Qt.rect(0, 0, 0, 0)
        root.mode = mode
        root.outName = NiriService.currentOutput || Quickshell.screens[0].name
        root.windowId = NiriService.activeWindow?.id ?? -1
        root.seq++
        root.busy = true
        // The delay and the cursor are applied when the screen is frozen.
        grab.command = ["sh", "-c", (root.delay > 0 ? "sleep " + root.delay + "; " : "") + "grim " + (root.cursor ? "-c " : "") + "-t ppm -o " + root.outName + " \"" + root.frozen + "\""]
        grab.running = true
    }
    function setMode(m: string): void {
        root.mode = m
        if (root.scene) root.scene.setTool(m === "region" ? "select" : "arrow")
    }
    function cancel(): void {
        root.open = false
        Quickshell.execDetached(["rm", "-f", root.frozen])
    }
    function cycleDelay(): void { root.delay = root.delay === 0 ? 3 : (root.delay === 3 ? 5 : (root.delay === 5 ? 10 : 0)) }

    // action: copy | save | edit (edit is for window shots: they open in the editor window)
    function run(action: string): void {
        if (!root.ready || root.busy || root.exporting) return
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")
        const savePath = root.shotsDir + "/" + ts + ".png"
        const tmp = root.runtime + "/zerd-shot-out.png"
        const out = action === "save" ? savePath : tmp
        const copy = "wl-copy -t image/png < \"" + out + "\""
        const note = action === "save" ? "notify-send -a Screenshot -i \"" + out + "\" 'Screenshot saved' 'Pictures/Screenshots, and copied'" : "notify-send -a Screenshot -i \"" + out + "\" 'Screenshot copied' 'Paste it anywhere'"
        if (root.mode === "window") {
            // A window is rendered by niri itself.
            const make = "niri msg action screenshot-window --id " + root.windowId + " --path \"" + out + "\"" + (root.cursor ? " --show-pointer true" : "")
            let after = ""
            if (action === "edit") after = "qs -c zerd ipc call screenshot edit \"" + out + "\""
            else after = copy + "; " + note + (action === "copy" ? "; rm -f \"" + out + "\"" : "")
            root.open = false
            Quickshell.execDetached(["sh", "-c", make + " && { " + after + "; }; rm -f \"" + root.frozen + "\""])
            return
        }
        // Like grim: one pipeline from the frozen pixels, cropped once, PNG at the fastest setting, and the
        // overlay is gone the moment the key is pressed. Marks are the only reason to grab the scene first.
        const sc = root.screenObj.devicePixelRatio || 1
        const whole = root.mode !== "region" || !root.hasRegion
        const frozenNow = root.frozen
        const full = root.runtime + "/zerd-shot-full-" + root.seq + ".ppm"
        const pipeline = src => {
            const x = whole ? 0 : Math.round(root.selX * sc), y = whole ? 0 : Math.round(root.selY * sc)
            const w = whole ? Math.round(root.screenObj.width * sc) : Math.round(root.selW * sc), h = whole ? Math.round(root.screenObj.height * sc) : Math.round(root.selH * sc)
            const crop = "magick \"" + src + "\" -crop " + w + "x" + h + "+" + x + "+" + y + " +repage -define png:compression-level=1"
            let script
            if (action === "save") script = crop + " \"" + savePath + "\" && { wl-copy -t image/png < \"" + savePath + "\"; notify-send -a Screenshot -i \"" + savePath + "\" 'Screenshot saved' 'Pictures/Screenshots, and copied'; }"
            else script = crop + " png:- | wl-copy -t image/png && notify-send -a Screenshot 'Screenshot copied' 'Paste it anywhere'"
            script += "; rm -f \"" + frozenNow + "\" \"" + full + "\""
            root.open = false
            Quickshell.execDetached(["sh", "-c", script])
        }
        const item = root.scene
        if (!item || !item.hasMarks) { pipeline(frozenNow); return }
        root.exporting = true
        item.grabToImage(r => {
            root.exporting = false
            pipeline(r.saveToFile(full) ? full : frozenNow)
        }, Qt.size(Math.round(item.width * sc), Math.round(item.height * sc)))
    }

    Process {
        id: grab
        onExited: (code) => {
            root.busy = false
            if (code === 0 && root.pending !== "") { if (root.pendingRect) { root.sel = Qt.rect(root.pendingRect[0], root.pendingRect[1], root.pendingRect[2], root.pendingRect[3]); root.pendingRect = null }; root.open = true; pendingRun.restart() }
            else if (code === 0) root.open = true
            else console.warn("screenshot: grim failed")
        }
    }

    // `take`: the overlay needs a moment to map before its scene can be exported.
    Timer {
        id: pendingRun
        interval: 250
        onTriggered: { const a = root.pending; root.pending = ""; if (a !== "") root.run(a) }
    }

    // The screenshot keys arrive through a FIFO (scripts/screenshot-key.sh): a few milliseconds, where a
    // `qs ipc` call takes close to a tenth of a second. `exec cat` ends when a writer closes, then listens again.
    Process {
        id: keyPipe
        running: true
        command: ["sh", "-c", "f=\"$XDG_RUNTIME_DIR/zerd-screenshot\"; pkill -f \"^cat $f\\$\" 2>/dev/null; [ -p \"$f\" ] || { rm -f \"$f\"; mkfifo -m 600 \"$f\"; }; exec cat \"$f\""]
        stdout: SplitParser {
            onRead: line => {
                const c = line.trim()
                if (c === "region" || c === "screen" || c === "window") root.begin(c)
            }
        }
        onExited: reopen.start()
    }
    Timer { id: reopen; interval: 2; onTriggered: keyPipe.running = true }

    ScreenshotEditor { id: editor }

    IpcHandler {
        target: "screenshot"
        function open(): void { root.begin("region") }
        function region(): void { root.begin("region") }
        function window(): void { root.begin("window") }
        function screen(): void { root.begin("screen") }
        function cancel(): void { root.cancel() }
        function edit(path: string): void { editor.edit(path) }
        // For scripts and fixed-area keybinds: take the area x, y, w, h straight away; action: copy or save.
        function area(x: int, y: int, w: int, h: int, action: string): void {
            if (root.open || root.busy) return
            root.pendingRect = [x, y, w, h]
            root.pending = action
            root.begin("region")
        }
        // mode: screen or window (the focused one); action: copy or save.
        function take(mode: string, action: string): void {
            if (root.open || root.busy) return
            root.pending = action
            root.begin(mode)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            visible: root.open && win.modelData.name === root.outName
            screen: modelData
            // Opaque: a full-screen surface that is not see-through is cheaper to put on screen.
            color: "#000000"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-screenshot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property bool annotating: marks.tool !== "select"
            readonly property bool whole: root.mode === "screen"
            readonly property bool cut: root.mode === "region" && root.hasRegion
            // The rectangle that will be saved, in the overlay's pixels.
            readonly property rect area: win.whole ? Qt.rect(0, 0, win.width, win.height) : Qt.rect(root.selX, root.selY, root.selW, root.selH)

            // Pointer positions at the very edge snap to the edge, so the area can reach the corners.
            function snapTo(v: real, max: real): real { return v <= 3 ? 0 : (v >= max - 3 ? max : v) }

            // ---- The scene: the frozen screen and the marks on it (this is what gets saved)
            Item {
                id: scene
                anchors.fill: parent
                readonly property bool hasMarks: marks.items.length > 0
                function setTool(t: string): void { marks.tool = t }
                Image {
                    id: shot
                    anchors.fill: parent
                    source: win.visible ? "file://" + root.frozen : ""
                    cache: false
                    fillMode: Image.Stretch
                }
                AnnotationLayer {
                    id: marks
                    anchors.fill: parent
                    tool: "select"
                    imageSource: shot.source
                    active: root.mode !== "window" && win.annotating && (win.cut || win.whole)
                    onTextFinished: keys.forceActiveFocus()
                }
            }
            onVisibleChanged: {
                if (visible) {
                    root.scene = scene
                    marks.clearAll()
                    marks.tool = root.mode === "region" ? "select" : "arrow"
                    keys.forceActiveFocus()
                } else if (root.scene === scene) root.scene = null
            }

            // ---- The selection: border, size and handles
            Item {
                visible: win.cut
                x: root.selX; y: root.selY; width: root.selW; height: root.selH
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: BarStyle.accent }
                Repeater {
                    model: win.annotating ? [] : [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 10; height: 10; radius: 5
                        x: parent.width * modelData[0] - 5; y: parent.height * modelData[1] - 5
                        color: BarStyle.accent
                        border.width: 2; border.color: BarStyle.surface
                    }
                }
                Rectangle {
                    x: 0; y: root.selY > 40 ? -height - 8 : 8
                    width: sizeText.implicitWidth + 18; height: 24; radius: 12
                    color: BarStyle.surface
                    BarText { id: sizeText; anchors.centerIn: parent; font.pixelSize: 12; text: Math.round(root.selW * (root.screenObj.devicePixelRatio || 1)) + " × " + Math.round(root.selH * (root.screenObj.devicePixelRatio || 1)) }
                }
            }

            // ---- Drawing and adjusting the area (the select tool)
            MouseArea {
                id: area
                anchors.fill: parent
                enabled: root.mode === "region" && !win.annotating
                cursorShape: Qt.CrossCursor
                property string kind: ""
                property real px: 0
                property real py: 0
                property real lx: 0
                property real ly: 0
                property bool spaceDown: false       // holding Space while dragging carries the box along, as in slurp
                property rect s0: Qt.rect(0, 0, 0, 0)

                function hit(x: real, y: real): string {
                    if (!root.hasRegion) return ""
                    const g = 10
                    const l = Math.abs(x - root.selX) <= g, r = Math.abs(x - (root.selX + root.selW)) <= g
                    const t = Math.abs(y - root.selY) <= g, b = Math.abs(y - (root.selY + root.selH)) <= g
                    const inX = x >= root.selX - g && x <= root.selX + root.selW + g
                    const inY = y >= root.selY - g && y <= root.selY + root.selH + g
                    if (!inX || !inY) return ""
                    const hx = l ? "l" : (r ? "r" : ""), hy = t ? "t" : (b ? "b" : "")
                    return hy + hx
                }
                onPressed: m => {
                    const h = hit(m.x, m.y)
                    px = win.snapTo(m.x, win.width); py = win.snapTo(m.y, win.height)
                    lx = m.x; ly = m.y
                    s0 = Qt.rect(root.selX, root.selY, root.selW, root.selH)
                    if (h === "") { kind = "new"; root.sel = Qt.rect(px, py, 0, 0) }
                    else kind = h
                }
                onPositionChanged: m => {
                    if (!pressed) return
                    const W = win.width, H = win.height
                    const cx = win.snapTo(Math.max(0, Math.min(W, m.x)), W), cy = win.snapTo(Math.max(0, Math.min(H, m.y)), H)
                    if (spaceDown && kind !== "") {
                        // Move the whole box; the corner you were pulling moves with it.
                        const dx = Math.max(-root.selX, Math.min(W - root.selX - root.selW, m.x - lx))
                        const dy = Math.max(-root.selY, Math.min(H - root.selY - root.selH, m.y - ly))
                        root.sel = Qt.rect(root.selX + dx, root.selY + dy, root.selW, root.selH)
                        px += dx; py += dy
                        s0 = Qt.rect(s0.x + dx, s0.y + dy, s0.width, s0.height)
                        lx = m.x; ly = m.y
                        return
                    }
                    lx = m.x; ly = m.y
                    if (kind === "new") {
                        root.sel = Qt.rect(Math.min(px, cx), Math.min(py, cy), Math.abs(cx - px), Math.abs(cy - py))
                    } else if (kind !== "") {
                        let x0 = s0.x, y0 = s0.y, x1 = s0.x + s0.width, y1 = s0.y + s0.height
                        if (kind.includes("l")) x0 = cx
                        if (kind.includes("r")) x1 = cx
                        if (kind.includes("t")) y0 = cy
                        if (kind.includes("b")) y1 = cy
                        root.sel = Qt.rect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0))
                    }
                }
                onReleased: { kind = ""; spaceDown = false }
            }

            // ---- Window mode: the windows to pick from
            Rectangle {
                id: winList
                visible: root.mode === "window"
                width: 420
                height: Math.min(win.height - 260, listView.contentHeight + 24 + 56)
                x: Math.round((win.width - width) / 2)
                y: Math.round((win.height - height) / 2 - 40)
                radius: 22
                color: BarStyle.surface
                border.width: 1; border.color: BarStyle.border
                MouseArea { anchors.fill: parent }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                    height: 40; radius: 20
                    color: openArea.pressed ? BarStyle.border : BarStyle.accent
                    BarText { anchors.centerIn: parent; text: "Open in editor"; font.weight: Font.DemiBold; color: BarStyle.onAccent }
                    MouseArea { id: openArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run("edit") }
                }
                ListView {
                    id: listView
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 12; bottomMargin: 64 }
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.visible ? (NiriService.windows ?? []) : []
                    delegate: Rectangle {
                        id: wrow
                        required property var modelData
                        width: listView.width
                        height: 44
                        radius: 14
                        readonly property bool picked: root.windowId === modelData.id
                        color: picked ? BarStyle.plateHover : (wHover.hovered ? Qt.rgba(BarStyle.plateHover.r, BarStyle.plateHover.g, BarStyle.plateHover.b, 0.5) : "transparent")
                        border.width: picked ? 1 : 0; border.color: BarStyle.accent
                        Behavior on color { ColorAnimation { duration: 80 } }
                        SmartAppIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: AppSearch.lookupDesktopEntry(wrow.modelData.app_id ?? "")?.icon || AppSearch.guessIcon(wrow.modelData.app_id ?? ""); iconSize: 26 }
                        BarText { x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62; elide: Text.ElideRight; text: wrow.modelData.title || wrow.modelData.app_id || "Window" }
                        HoverHandler { id: wHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.windowId = wrow.modelData.id; onDoubleClicked: { root.windowId = wrow.modelData.id; root.run("edit") } }
                    }
                }
            }

            // ---- Keys
            Item {
                id: keys
                focus: true
                property bool spaceFired: false
                property double openedAt: 0
                Connections { target: win; function onVisibleChanged() { if (win.visible) { keys.spaceFired = false; keys.openedAt = Date.now(); keys.forceActiveFocus() } } }
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Space) {
                        // A Space still held from typing arrives as an auto-repeat, so a repeat counts too, once,
                        // after a short moment (so a key still down while the overlay opens does not fire at once).
                        if (area.pressed) area.spaceDown = true
                        else if (!keys.spaceFired && (!event.isAutoRepeat || Date.now() - keys.openedAt > 250)) {
                            keys.spaceFired = true
                            root.run(root.mode === "window" ? "edit" : "copy")
                        }
                    }
                    else if (event.key === Qt.Key_Escape) root.cancel()
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.run(root.mode === "window" ? "edit" : "copy")
                    else if (ctrl && event.key === Qt.Key_S) root.run("save")
                    else if (ctrl && event.key === Qt.Key_C) root.run("copy")
                    else if (ctrl && event.key === Qt.Key_Z) marks.undo()
                    else if (ctrl && event.key === Qt.Key_Y) marks.redo()
                    else if (event.key === Qt.Key_1) root.setMode("region")
                    else if (event.key === Qt.Key_2) root.setMode("window")
                    else if (event.key === Qt.Key_3) root.setMode("screen")
                    else if (event.key === Qt.Key_D) root.cycleDelay()
                    else if (root.mode === "window") return
                    else if (event.key === Qt.Key_S && root.mode === "region") marks.tool = "select"
                    else if (event.key === Qt.Key_B) marks.tool = "brush"
                    else if (event.key === Qt.Key_I) marks.tool = "line"
                    else if (event.key === Qt.Key_Z) marks.tool = "arrow"
                    else if (event.key === Qt.Key_R) marks.tool = "rect"
                    else if (event.key === Qt.Key_E) marks.tool = "ellipse"
                    else if (event.key === Qt.Key_T) marks.tool = "text"
                    else if (event.key === Qt.Key_M) marks.tool = "marker"
                    else if (event.key === Qt.Key_U) marks.tool = "blur"
                    else if (event.key === Qt.Key_G) marks.tool = "highlight"
                    else return
                    event.accepted = true
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_Space && !event.isAutoRepeat) { area.spaceDown = false; keys.spaceFired = false } }
            }

            // ---- The tools and the place to save, under the selection
            Rectangle {
                id: dock
                visible: root.mode !== "window" && (win.cut || win.whole) && area.kind === ""
                readonly property real inner: Math.max(toolsRow.implicitWidth + 24 + actions.implicitWidth, styleRow.implicitWidth)
                width: inner + 28
                height: toolsRow.implicitHeight + 46 + 28
                radius: 22
                color: BarStyle.surface
                border.width: 1; border.color: BarStyle.border
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#99000000"; shadowBlur: 0.9; shadowVerticalOffset: 6; shadowOpacity: 0.55 }
                readonly property real wantX: win.area.x + win.area.width / 2 - width / 2
                x: Math.max(12, Math.min(win.width - width - 12, wantX))
                y: {
                    const below = win.area.y + win.area.height + 6
                    if (below + height + 12 <= win.height) return below
                    const above = win.area.y - height - 6
                    if (above >= 12) return above
                    return win.height - height - 24
                }
                opacity: win.visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                MouseArea { anchors.fill: parent }

                Item {
                    x: 14; y: 12
                    width: dock.inner; height: 36
                    AnnotationTools { id: toolsRow; ann: marks; withSelect: root.mode === "region" }
                    Row {
                        id: actions
                        anchors.right: parent.right
                        spacing: 8
                        Rectangle {
                            width: copyRow.implicitWidth + 28; height: 36; radius: 18
                            color: copyArea.pressed ? BarStyle.border : BarStyle.plateHover
                            border.width: 1; border.color: BarStyle.border
                            scale: copyArea.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 70 } }
                            Row {
                                id: copyRow; anchors.centerIn: parent; spacing: 7
                                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "content_copy"; size: 18; color: BarStyle.text }
                                BarText { anchors.verticalCenter: parent.verticalCenter; text: "Copy"; font.weight: Font.DemiBold }
                            }
                            MouseArea { id: copyArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run("copy") }
                            BarTip { text: "Copy  (Space or Enter)"; external: copyHover.hovered }
                            HoverHandler { id: copyHover }
                        }
                        Rectangle {
                            width: saveRow.implicitWidth + 28; height: 36; radius: 18
                            color: saveArea.pressed ? BarStyle.border : BarStyle.accent
                            scale: saveArea.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: 70 } }
                            Row {
                                id: saveRow; anchors.centerIn: parent; spacing: 7
                                BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "save"; size: 18; color: BarStyle.onAccent }
                                BarText { anchors.verticalCenter: parent.verticalCenter; text: "Save"; font.weight: Font.DemiBold; color: BarStyle.onAccent }
                            }
                            MouseArea { id: saveArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.run("save") }
                            BarTip { text: "Save to Pictures/Screenshots  (Ctrl+S)"; external: saveHover.hovered }
                            HoverHandler { id: saveHover }
                        }
                    }
                }
                AnnotationStyle { id: styleRow; ann: marks; x: 14; y: 12 + 36 + 10 }
            }

            // One line of help while there is nothing selected yet.
            Rectangle {
                visible: opacity > 0.01
                opacity: root.mode === "region" && !root.hasRegion && area.kind === "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                width: hintText.implicitWidth + 36; height: 40; radius: 20
                x: Math.round((win.width - width) / 2); y: win.height - height - 96
                color: BarStyle.surface
                border.width: 1; border.color: BarStyle.border
                BarText { id: hintText; anchors.centerIn: parent; text: "Drag to select an area   ·   Space copies (nothing selected = whole screen)   ·   Esc cancels"; font.pixelSize: 13; color: BarStyle.subtext }
            }
        }
    }
}
