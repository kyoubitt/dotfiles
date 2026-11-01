pragma ComponentBehavior: Bound

import QtQuick

// Marks drawn over a picture: brush, line, arrow, rectangle, ellipse, text, numbered marker, blur
// (pixelate), highlight and a crop box. Everything lives in this item's own pixels, so the same layer
// works at image size (the editor window) and on the frozen screen (the capture overlay). Finished
// marks are painted on one canvas, the stroke being drawn on another, so dragging stays light.
Item {
    id: root

    // The picture underneath, used by the blur boxes.
    property url imageSource
    property real viewScale: 1            // how much the host shrinks this layer (keeps thin borders visible)
    property bool active: true            // the pointer draws while true
    // The two full-screen canvases exist only once something may be drawn, so an overlay that is just being
    // used to pick an area carries none of their cost. Hosts that draw from the start set this true.
    property bool engaged: false
    onToolChanged: if (tool !== "select") engaged = true

    property string tool: "arrow"
    property color ink: BarStyle.accent
    property real inkSize: 6
    property bool fill: false

    property var items: []                // finished marks
    property var cur: null                // the mark being drawn (changed in place while dragging)
    property int curRev: 0                // bumped while a blur box is dragged, so its preview follows
    property rect crop: Qt.rect(0, 0, 0, 0)
    property var cropDraft: null
    property var history: []              // snapshots {items, crop}
    property int hist: -1
    property int markerCount: 0
    property bool typing: false
    readonly property bool canUndo: hist > 0
    readonly property bool canRedo: hist < history.length - 1
    readonly property var blurs: items.filter(i => i.t === "blur")

    signal textFinished()

    function snap(): void {
        history = history.slice(0, hist + 1).concat([{ items: items.slice(), crop: crop }])
        hist = history.length - 1
    }
    function restore(): void {
        const s = history[hist]
        items = s.items.slice()
        crop = s.crop
        repaintAll()
    }
    function undo(): void { if (hist > 0) { hist--; restore() } }
    function redo(): void { if (hist < history.length - 1) { hist++; restore() } }
    function clearAll(): void { items = []; markerCount = 0; snap(); repaintAll() }
    function commit(it: var): void { items = items.concat([it]); snap(); repaintAll() }
    function applyCrop(r: rect): void { crop = r; cropDraft = null; snap() }
    Component.onCompleted: snap()
    function repaintAll(): void { if (paintLoader.item) paintLoader.item.requestPaint() }
    function repaintLive(): void { if (liveLoader.item) liveLoader.item.requestPaint() }

    function newItem(tool: string, x: real, y: real): var {
        const it = { t: tool, c: String(ink), s: inkSize, f: fill, x0: x, y0: y, x1: x, y1: y }
        if (tool === "brush") it.pts = [[x, y]]
        return it
    }
    function normRect(it: var): var { return { x: Math.min(it.x0, it.x1), y: Math.min(it.y0, it.y1), w: Math.abs(it.x1 - it.x0), h: Math.abs(it.y1 - it.y0) } }

    function drawItem(ctx: var, it: var): void {
        ctx.save()
        ctx.strokeStyle = it.c
        ctx.fillStyle = it.c
        ctx.lineWidth = it.s
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        if (it.t === "brush") {
            const p = it.pts
            ctx.beginPath()
            ctx.moveTo(p[0][0], p[0][1])
            for (let i = 1; i < p.length - 1; i++) ctx.quadraticCurveTo(p[i][0], p[i][1], (p[i][0] + p[i + 1][0]) / 2, (p[i][1] + p[i + 1][1]) / 2)
            if (p.length > 1) ctx.lineTo(p[p.length - 1][0], p[p.length - 1][1])
            else ctx.lineTo(p[0][0] + 0.1, p[0][1])
            ctx.stroke()
        } else if (it.t === "line") {
            ctx.beginPath(); ctx.moveTo(it.x0, it.y0); ctx.lineTo(it.x1, it.y1); ctx.stroke()
        } else if (it.t === "arrow") {
            // A real arrow: the shaft stops where the head begins, so the tip stays sharp, and the head
            // grows with the stroke (a notched, swept-back head).
            const dx = it.x1 - it.x0, dy = it.y1 - it.y0, len = Math.hypot(dx, dy)
            if (len < 2) { ctx.restore(); return }
            const ux = dx / len, uy = dy / len
            const L = Math.min(len * 0.9, Math.max(20, it.s * 4.5)), W = L * 0.55
            const bx = it.x1 - ux * L * 0.82, by = it.y1 - uy * L * 0.82     // where the shaft ends (inside the notch)
            ctx.beginPath(); ctx.moveTo(it.x0, it.y0); ctx.lineTo(bx, by); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(it.x1, it.y1)
            ctx.lineTo(it.x1 - ux * L - uy * W, it.y1 - uy * L + ux * W)
            ctx.lineTo(bx, by)
            ctx.lineTo(it.x1 - ux * L + uy * W, it.y1 - uy * L - ux * W)
            ctx.closePath(); ctx.fill()
        } else if (it.t === "rect") {
            const r = normRect(it)
            if (it.f) ctx.fillRect(r.x, r.y, r.w, r.h); else ctx.strokeRect(r.x, r.y, r.w, r.h)
        } else if (it.t === "ellipse") {
            const r = normRect(it)
            ctx.beginPath(); ctx.ellipse(r.x, r.y, r.w, r.h)
            if (it.f) ctx.fill(); else ctx.stroke()
        } else if (it.t === "highlight") {
            const r = normRect(it)
            ctx.globalAlpha = 0.38
            ctx.fillRect(r.x, r.y, r.w, r.h)
        } else if (it.t === "marker") {
            const R = Math.max(12, it.s * 2.6)
            ctx.beginPath(); ctx.arc(it.x0, it.y0, R, 0, 2 * Math.PI); ctx.fill()
            const lum = parseInt(it.c.slice(1, 3), 16) * 0.3 + parseInt(it.c.slice(3, 5), 16) * 0.59 + parseInt(it.c.slice(5, 7), 16) * 0.11
            ctx.fillStyle = lum > 150 ? "#000000" : "#ffffff"
            ctx.font = "bold " + Math.round(R * 1.15) + "px sans-serif"
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            ctx.fillText(String(it.n), it.x0, it.y0 + 1)
        } else if (it.t === "text") {
            ctx.font = Math.round(it.s * 3.2 + 8) + "px sans-serif"
            ctx.textBaseline = "top"
            ctx.fillText(it.text, it.x0, it.y0)
        }
        ctx.restore()
    }

    // Blur: the same picture, shrunk to a few blocks and stretched back.
    Repeater {
        model: root.blurs
        delegate: Item {
            required property var modelData
            readonly property var r: root.normRect(modelData)
            x: r.x; y: r.y; width: Math.max(1, r.w); height: Math.max(1, r.h)
            clip: true
            layer.enabled: true
            layer.smooth: false
            layer.textureSize: Qt.size(Math.max(1, Math.round(width / 14)), Math.max(1, Math.round(height / 14)))
            Image { x: -parent.x; y: -parent.y; width: root.width; height: root.height; source: root.imageSource; cache: false }
        }
    }
    // The blur box being dragged: one fixed item that follows the pointer.
    Item {
        id: liveBlur
        readonly property var r: { root.curRev; return root.cur && root.cur.t === "blur" ? root.normRect(root.cur) : ({ x: 0, y: 0, w: 0, h: 0 }) }
        visible: r.w > 1 && r.h > 1
        x: r.x; y: r.y; width: Math.max(1, r.w); height: Math.max(1, r.h)
        clip: true
        layer.enabled: visible
        layer.smooth: false
        layer.textureSize: Qt.size(Math.max(1, Math.round(width / 14)), Math.max(1, Math.round(height / 14)))
        Image { x: -parent.x; y: -parent.y; width: root.width; height: root.height; source: root.imageSource; cache: false }
    }

    Loader {
        id: paintLoader
        anchors.fill: parent
        active: root.engaged
        onLoaded: root.repaintAll()
        sourceComponent: Canvas {
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                for (const it of root.items) if (it.t !== "blur") root.drawItem(ctx, it)
            }
        }
    }
    Loader {
        id: liveLoader
        anchors.fill: parent
        active: root.engaged
        sourceComponent: Canvas {
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (root.cur && root.cur.t !== "blur") root.drawItem(ctx, root.cur)
            }
        }
    }

    // The crop being chosen.
    Rectangle {
        visible: root.tool === "crop" && root.cropDraft !== null
        x: root.cropDraft ? root.cropDraft.x : 0; y: root.cropDraft ? root.cropDraft.y : 0
        width: root.cropDraft ? root.cropDraft.w : 0; height: root.cropDraft ? root.cropDraft.h : 0
        color: "transparent"
        border.width: Math.max(2, 2 / root.viewScale); border.color: "white"
    }

    // Text being typed.
    Rectangle {
        id: textBox
        property real tx: 0
        property real ty: 0
        visible: root.typing
        x: tx; y: ty
        width: Math.max(40, textIn.contentWidth + 16); height: textIn.contentHeight + 8
        color: "transparent"
        border.width: Math.max(1, 1.5 / root.viewScale); border.color: root.ink
        TextInput {
            id: textIn
            x: 8; y: 4
            color: root.ink
            font.pixelSize: Math.round(root.inkSize * 3.2 + 8)
            onAccepted: textBox.finish(true)
            Keys.onEscapePressed: textBox.finish(false)
        }
        function begin(x: real, y: real): void { tx = x; ty = y; textIn.text = ""; root.typing = true; textIn.forceActiveFocus() }
        function finish(keep: bool): void {
            if (!root.typing) return
            root.typing = false
            root.textFinished()
            if (keep && textIn.text.trim().length > 0) root.commit({ t: "text", c: String(root.ink), s: root.inkSize, x0: tx, y0: ty, text: textIn.text })
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        cursorShape: Qt.CrossCursor
        onPressed: m => {
            if (root.typing) { textBox.finish(true); return }
            if (root.tool === "text") { textBox.begin(m.x, m.y); return }
            if (root.tool === "marker") { root.markerCount++; root.commit({ t: "marker", c: String(root.ink), s: root.inkSize, x0: m.x, y0: m.y, n: root.markerCount }); return }
            if (root.tool === "crop") { root.cropDraft = { x: m.x, y: m.y, w: 0, h: 0, ox: m.x, oy: m.y }; return }
            root.cur = root.newItem(root.tool, m.x, m.y)
            repaintLive()
        }
        onPositionChanged: m => {
            if (!pressed) return
            const x = Math.max(0, Math.min(root.width, m.x)), y = Math.max(0, Math.min(root.height, m.y))
            if (root.tool === "crop" && root.cropDraft) {
                const d = root.cropDraft
                root.cropDraft = { x: Math.min(d.ox, x), y: Math.min(d.oy, y), w: Math.abs(x - d.ox), h: Math.abs(y - d.oy), ox: d.ox, oy: d.oy }
                return
            }
            const it = root.cur
            if (!it) return
            if (it.t === "brush") {
                const last = it.pts[it.pts.length - 1]
                if (Math.abs(x - last[0]) + Math.abs(y - last[1]) < 1.5) return
                it.pts.push([x, y])
            } else { it.x1 = x; it.y1 = y }
            if (it.t === "blur") root.curRev++
            else repaintLive()
        }
        onReleased: {
            const it = root.cur
            if (!it) return
            root.cur = null
            repaintLive()
            const moved = it.t === "brush" ? it.pts.length > 1 : (Math.abs(it.x1 - it.x0) + Math.abs(it.y1 - it.y0) > 3)
            if (moved) root.commit(it)
            root.curRev++
        }
    }
}
