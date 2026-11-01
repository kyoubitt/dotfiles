import QtQuick

// A stack of panel sections that can be reordered by dragging the grip in each header.
// The grabbed section follows the pointer; the others slide out of the way while it moves, a
// scrolling panel follows when the pointer nears its top or bottom edge, and on release the
// section glides into the gap before `moved` reports the new order once.
Item {
    id: root

    // Every section name (stable, so moving one never rebuilds the others).
    property var names: []
    // The saved order and the names switched off.
    property var order: []
    property var hidden: []
    // name -> Component producing the section.
    property var comps: ({})
    property real spacing: 10
    signal moved(var list)

    readonly property var visibleNames: root.order.filter(n => !root.hidden.includes(n))
    property string dragName: ""
    property real grabOffset: 0
    property real globalY: 0
    property real rootTop: 0
    // Order-independent, so following the pointer never feeds back into the layout.
    readonly property real totalH: {
        let t = 0
        for (const n of root.visibleNames) t += root.hOf(n) + root.spacing
        return Math.max(0, t - root.spacing)
    }
    readonly property real dragTop: {
        const room = Math.max(0, root.totalH - root.hOf(root.dragName))
        return Math.max(0, Math.min(room, root.globalY - root.rootTop - root.grabOffset))
    }
    // The scrolling panel this sits in, if any.
    readonly property Item flick: { let p = root.parent; while (p && p.contentY === undefined) p = p.parent; return p }

    function itemOf(name: string): var {
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i)
            if (it && it.name === name) return it
        }
        return null
    }
    function hOf(name: string): real {
        const it = root.itemOf(name)
        return it && it.shown ? it.height : 0
    }
    // The order as it would be if the section were dropped now.
    readonly property var live: {
        const vis = root.visibleNames
        if (root.dragName === "" || !vis.includes(root.dragName)) return vis
        const others = vis.filter(n => n !== root.dragName)
        const centre = root.dragTop + root.hOf(root.dragName) / 2
        let y = 0, at = 0
        for (const n of others) {
            const h = root.hOf(n)
            if (y + h / 2 < centre) at++
            y += h + root.spacing
        }
        const out = others.slice()
        out.splice(at, 0, root.dragName)
        return out
    }
    function slotY(name: string): real {
        let y = 0
        for (const n of root.live) {
            if (n === name) return y
            y += root.hOf(n) + root.spacing
        }
        return 0
    }
    implicitHeight: root.totalH
    height: implicitHeight

    function refreshTop(): void { root.rootTop = root.mapToItem(null, 0, 0).y }
    function begin(name: string, gy: real, itemY: real): void {
        root.refreshTop()
        root.globalY = gy
        root.grabOffset = (gy - root.rootTop) - itemY
        root.dragName = name
        edge.start()
    }
    function finish(save: bool): void {
        edge.stop()
        if (root.dragName === "") return
        const name = root.dragName
        const vis = root.live
        const rest = root.order.filter(n => n !== name)
        const next = vis[vis.indexOf(name) + 1]
        rest.splice(next !== undefined ? rest.indexOf(next) : rest.length, 0, name)
        root.dragName = ""
        if (save) root.moved(rest)
    }

    // Scrolls the panel while the grabbed section is held near its top or bottom edge.
    Timer {
        id: edge
        interval: 16
        repeat: true
        onTriggered: {
            const f = root.flick
            if (f) {
                const py = root.globalY - f.mapToItem(null, 0, 0).y
                const zone = 56
                if (py < zone) f.contentY = Math.max(0, f.contentY - Math.max(2, (zone - py) / 3))
                else if (py > f.height - zone) f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY + Math.max(2, (py - (f.height - zone)) / 3)))
            }
            root.refreshTop()
        }
    }

    Repeater {
        id: rep
        model: root.names
        delegate: Loader {
            id: sec
            required property string modelData
            readonly property string name: modelData
            readonly property bool shown: !root.hidden.includes(modelData)
            readonly property bool dragging: root.dragName === modelData
            visible: shown
            width: root.width
            sourceComponent: root.comps[modelData]
            y: dragging ? root.dragTop : root.slotY(modelData)
            Behavior on y { enabled: !sec.dragging; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            z: dragging ? 10 : 0
            scale: dragging ? 1.02 : 1
            // Sections arrive one after another once the panel is half open.
            readonly property real rise: Math.max(0, Math.min(1, (BarState.panelEnter - 0.45 - Math.min(root.names.indexOf(modelData), 6) * 0.06) / 0.3))
            opacity: (dragging ? 0.92 : 1) * rise
            transform: Translate { y: (1 - sec.rise) * 8 }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 100 } }

            // While anything is dragged, every section folds to its header, so the list is short
            // and the grabbed one is never a tall card covering the others.
            Binding { target: sec.item; property: "collapsed"; value: root.dragName !== ""; when: sec.item !== null }

            // Grab here and drag up or down.
            Item {
                z: 5
                x: sec.width - 64; y: 12; width: 24; height: 24
                BarIcon { anchors.centerIn: parent; name: "drag_indicator"; size: 18; color: grip.pressed || gripHv.hovered ? BarStyle.text : BarStyle.subtext }
                HoverHandler { id: gripHv }
                MouseArea {
                    id: grip
                    anchors.fill: parent; anchors.margins: -5
                    preventStealing: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: m => root.begin(sec.name, grip.mapToItem(null, m.x, m.y).y, sec.y)
                    onPositionChanged: m => { if (pressed) root.globalY = grip.mapToItem(null, m.x, m.y).y }
                    onReleased: root.finish(true)
                    onCanceled: root.finish(false)
                }
            }
        }
    }
}
