pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// The wallpaper picker: a row of tall slanted slices over a dimmed screen; the focused slice opens wide
// to show the picture, the others fade away from it. Hover or arrows move the focus, a click or Enter
// applies it (through the shell's own transition engine, WallpaperStage). Filters along the top: All,
// History, Favourites and the colours; type to search. R random, F favourite, Tab filter, Esc close.
// `ipc call wallpaper toggle|open|close|random|next|prev`.
Scope {
    id: root

    property bool open: false
    property string filter: "all"
    property string query: ""
    property int index: 0
    property bool chipsPinned: false

    readonly property var colorNames: ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]
    readonly property var colorHex: ({ Red: "#ff5d5d", Orange: "#ffa14d", Yellow: "#ffd166", Green: "#06d6a0", Blue: "#4c9bf0", Purple: "#a77bf0", Pink: "#ff7eb6", Monochrome: "#a9a9a9" })

    readonly property var view: {
        const all = WallpaperState.items
        let list = all
        if (root.filter === "history") list = WallpaperState.history.map(p => all.find(i => i.path === p)).filter(i => i)
        else if (root.filter === "favourites") list = all.filter(i => WallpaperState.favourites.includes(i.path))
        else if (root.filter !== "all") list = all.filter(i => i.color === root.filter)
        const q = root.query.trim().toLowerCase()
        if (q.length > 0) list = list.filter(i => i.name.toLowerCase().includes(q))
        if (root.filter === "history") return list
        const m = WallpaperState.sortMode
        const rank = c => { const k = root.colorNames.indexOf(c); return k < 0 ? 99 : k }
        return list.slice().sort(m === "name" ? (a, b) => a.name.localeCompare(b.name)
            : m === "newest" ? (a, b) => (b.mtime ?? 0) - (a.mtime ?? 0) || a.name.localeCompare(b.name)
            : (a, b) => rank(a.color) - rank(b.color) || (a.light ?? 50) - (b.light ?? 50) || a.name.localeCompare(b.name))
    }
    readonly property var filterOrder: ["all", "history", "favourites"].concat(root.colorNames)

    function show(): void {
        if (NiriService.inOverview || GlobalStates.screenLocked) return
        BarState.closeAll()
        WallpaperState.refresh()
        root.filter = "all"; root.query = ""; root.chipsPinned = false
        root.index = Math.max(0, root.view.findIndex(i => i.path === WallpaperState.current))
        root.open = true
    }
    function close(): void { root.open = false }
    Connections { target: BarState; function onCloseOverlays() { root.open = false } }
    function toggle(): void { if (root.open) root.close(); else root.show() }
    property double lastMove: 0
    property bool fast: false
    property real wheelAcc: 0
    function move(by: int): void {
        if (root.view.length === 0) return
        const now = Date.now()
        root.fast = now - root.lastMove < 240
        root.lastMove = now
        root.index = Math.max(0, Math.min(root.view.length - 1, root.index + by))
    }
    function cycleFilter(by: int): void {
        const i = root.filterOrder.indexOf(root.filter)
        root.filter = root.filterOrder[(i + by + root.filterOrder.length) % root.filterOrder.length]
        root.index = 0
        root.chipsPinned = true
    }
    function applyAt(i: int, ox: real, oy: real): void {
        const it = root.view[i]
        if (!it) return
        WallpaperState.apply(it.path, "", ox, oy)
        root.close()
    }
    onViewChanged: root.index = Math.max(0, Math.min(root.index, root.view.length - 1))

    // For keybinds and scripts.
    function step(by: int): void {
        const all = WallpaperState.items
        if (all.length === 0) return
        let at = all.findIndex(i => i.path === WallpaperState.current)
        at = (Math.max(0, at) + by + all.length) % all.length
        WallpaperState.apply(all[at].path, "", 0.5, 0.5)
    }
    function random(): void {
        const all = WallpaperState.items
        if (all.length === 0) return
        const pool = all.filter(i => i.path !== WallpaperState.current)
        WallpaperState.apply(pool[Math.floor(Math.random() * pool.length)].path, "", Math.random(), Math.random())
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle() }
        function open(): void { if (!root.open) root.show() }
        function close(): void { root.close() }
        function random(): void { if (WallpaperState.items.length === 0) WallpaperState.refresh(); root.random() }
        function next(): void { root.step(1) }
        function prev(): void { root.step(-1) }
    }
    Component.onCompleted: WallpaperState.refresh()

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool mine: Quickshell.screens.length < 2 || win.modelData.name === NiriService.currentOutput

            property real shown: root.open ? 1 : 0
            Behavior on shown { NumberAnimation { duration: root.open ? 150 : 110; easing.type: root.open ? Easing.OutCubic : Easing.InCubic } }

            screen: modelData
            visible: win.mine && (root.open || win.shown > 0.001)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-wallpaper"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Slice geometry follows the screen.
            readonly property int sliceH: Math.round(win.height * 0.44)
            readonly property int sliceW: Math.round(sliceH * 0.255)
            readonly property int skew: Math.round(sliceH * 0.066)
            readonly property int overlap: Math.round(sliceW * 0.2)
            readonly property int wFocus: Math.round(win.width * 0.5)

            Rectangle { anchors.fill: parent; color: "black"; opacity: 0.62 * win.shown }
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                onWheel: wheel => {
                    root.wheelAcc += wheel.angleDelta.y
                    while (Math.abs(root.wheelAcc) >= 120) { root.move(root.wheelAcc > 0 ? -1 : 1); root.wheelAcc -= root.wheelAcc > 0 ? 120 : -120 }
                }
            }

            // ---- Keys
            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) { if (root.query.length > 0) root.query = ""; else root.close() }
                    else if (event.key === Qt.Key_Left) root.move(ctrl ? -5 : -1)
                    else if (event.key === Qt.Key_Right) root.move(ctrl ? 5 : 1)
                    else if (event.key === Qt.Key_Home) root.index = 0
                    else if (event.key === Qt.Key_End) root.index = Math.max(0, root.view.length - 1)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.applyAt(root.index, 0.5, 0.5)
                    else if (event.key === Qt.Key_Tab) root.cycleFilter(1)
                    else if (event.key === Qt.Key_Backtab) root.cycleFilter(-1)
                    else if (event.key === Qt.Key_Backspace) root.query = root.query.slice(0, -1)
                    else if (ctrl && event.key === Qt.Key_R) root.random()
                    else if (event.text.length === 1 && event.text >= " " && !ctrl) {
                        const lower = event.text.toLowerCase()
                        if (root.query.length === 0 && lower === "r") { root.random(); root.close() }
                        else if (root.query.length === 0 && lower === "f") { const it = root.view[root.index]; if (it) WallpaperState.toggleFavourite(it.path) }
                        else if (root.query.length === 0 && lower === "s") { WallpaperState.cycleSort(); root.index = 0 }
                        else root.query += event.text
                    }
                    else return
                    event.accepted = true
                }
            }
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            // ---- Filters along the top: they fade in with the pointer, a search, or Tab
            Item {
                id: chips
                readonly property bool on: root.query.length > 0 || root.chipsPinned || topHover.hovered
                width: chipRow.implicitWidth; height: 40
                x: Math.round((win.width - width) / 2); y: Math.round(win.height * 0.07)
                opacity: win.shown * (on ? 1 : 0.0)
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Row {
                    id: chipRow
                    spacing: 6
                    component Chip: Rectangle {
                        id: chip
                        property string key
                        property string label
                        property color dot: "transparent"
                        readonly property bool picked: root.filter === key
                        height: 36
                        width: chipContent.implicitWidth + 26
                        radius: 18
                        color: picked ? BarStyle.accent : (chipHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.45))
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Row {
                            id: chipContent
                            anchors.centerIn: parent; spacing: 7
                            Rectangle { visible: chip.dot.a > 0; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: chip.dot }
                            BarText { visible: chip.label.length > 0; anchors.verticalCenter: parent.verticalCenter; text: chip.label; font.pixelSize: 13; font.weight: Font.DemiBold; color: chip.picked ? BarStyle.onAccent : "white" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.filter = chip.key; root.index = 0 } }
                        HoverHandler { id: chipHover }
                    }
                    Chip { key: "all"; label: "All" }
                    Chip { key: "history"; label: "History" }
                    Chip { key: "favourites"; label: "Favourites" }
                    Repeater { model: root.colorNames; delegate: Chip { required property string modelData; key: modelData; label: ""; dot: root.colorHex[modelData] } }
                }
            }
            // The pointer near the top brings the filters in.
            Item { x: 0; y: 0; width: win.width; height: Math.round(win.height * 0.2); HoverHandler { id: topHover } }

            // The search text and the transition chip.
            Rectangle {
                visible: root.query.length > 0
                x: Math.round((win.width - width) / 2); y: Math.round(win.height * 0.07) + 48
                width: searchText.implicitWidth + 34; height: 34; radius: 17
                color: Qt.rgba(0, 0, 0, 0.55); border.width: 1; border.color: BarStyle.accent
                BarText { id: searchText; anchors.centerIn: parent; text: "Search: " + root.query; font.pixelSize: 13; color: "white" }
            }
            Rectangle {
                x: kindChip.x - width - 8; y: Math.round(win.height * 0.07)
                width: sortRow.implicitWidth + 28; height: 36; radius: 18
                color: sortHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.45)
                Behavior on color { ColorAnimation { duration: 90 } }
                Row {
                    id: sortRow
                    anchors.centerIn: parent; spacing: 7
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "sort"; size: 18; color: "white" }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: "Sort: " + WallpaperState.sortMode; font.pixelSize: 13; color: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { WallpaperState.cycleSort(); root.index = 0 } }
                HoverHandler { id: sortHover }
            }
            Rectangle {
                id: kindChip
                x: win.width - width - Math.round(win.width * 0.03); y: Math.round(win.height * 0.07)
                width: kindRow.implicitWidth + 28; height: 36; radius: 18
                color: kindHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.45)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                opacity: win.shown
                Behavior on color { ColorAnimation { duration: 100 } }
                Row {
                    id: kindRow
                    anchors.centerIn: parent; spacing: 7
                    BarIcon { anchors.verticalCenter: parent.verticalCenter; name: "animation"; size: 18; color: "white" }
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: WallpaperState.fixedKind === "random" ? "Random transition" : WallpaperState.fixedKind; font.pixelSize: 13; color: "white" }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const all = ["random"].concat(WallpaperState.kinds)
                        WallpaperState.setKind(all[(all.indexOf(WallpaperState.fixedKind) + 1) % all.length])
                    }
                }
                HoverHandler { id: kindHover }
            }

            // ---- The slices. One number, `pos`, glides to the focus; every slice's place and width follow from it.
            property real pos: root.index
            Behavior on pos { enabled: win.shown > 0.5; NumberAnimation { duration: root.fast ? 150 : 260; easing.type: Easing.OutCubic } }
            readonly property bool moving: Math.abs(pos - root.index) > 0.02
            readonly property real step: sliceW - overlap
            readonly property real firstGap: wFocus / 2 - overlap + sliceW / 2
            // Centre of a slice that is `d` places from the focus, and its width; both piecewise-linear.
            function centreOf(d: real): real {
                const a = Math.abs(d), sgn = d < 0 ? -1 : 1
                return sgn * (a <= 1 ? a * firstGap : firstGap + (a - 1) * step)
            }
            function widthOf(d: real): real { return sliceW + (wFocus - sliceW) * Math.max(0, 1 - Math.abs(d)) }

            Loader {
                id: stage
                active: win.shown > 0.001
                x: 0; width: win.width
                y: Math.round(win.height * 0.5 - win.sliceH / 2 - win.height * 0.02)
                height: win.sliceH
                sourceComponent: Item {
                    Repeater {
                        model: root.view
                        delegate: Item {
                            id: sl
                            required property var modelData
                            required property int index
                            readonly property real d: index - win.pos
                            readonly property bool focused: root.index === index
                            readonly property bool near: Math.abs(d) < 8
                            readonly property bool fav: WallpaperState.favourites.includes(modelData.path)
                            readonly property bool isCurrent: modelData.path === WallpaperState.current
                            readonly property string thumb: near ? WallpaperState.thumbUrl(modelData.path) : ""
                            property bool arrived: false
                            property real rise: arrived ? 1 : 0
                            Behavior on rise { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                            // They rise in from the centre outwards.
                            Timer { running: sl.near; interval: win.shown > 0.6 ? 0 : Math.min(Math.abs(sl.index - root.index), 9) * 14; onTriggered: sl.arrived = true }

                            visible: near
                            width: win.widthOf(d)
                            height: win.sliceH
                            x: win.width / 2 + win.centreOf(d) - width / 2
                            y: (1 - rise) * 24
                            z: 10 - Math.min(10, Math.abs(d))
                            opacity: rise * Math.max(0, 1 - Math.max(0, Math.abs(d) - 2) / 6) * win.shown

                            // The slanted window: clipped, then sheared; the picture inside is sheared back, so only the
                            // outline leans.
                            Item {
                                id: slant
                                anchors.fill: parent
                                clip: true
                                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -win.skew / win.sliceH, 0, win.skew / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }

                                Rectangle { anchors.fill: parent; color: "#202024" }
                                Item {
                                    anchors.fill: parent
                                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, win.skew / win.sliceH, 0, -win.skew / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                                    Image {
                                        width: win.wFocus + win.skew; x: Math.round((sl.width - width) / 2); height: parent.height
                                        source: sl.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        opacity: status === Image.Ready ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                    // Name and star: only as the slice opens wide.
                                    readonly property real open: Math.max(0, 1 - Math.abs(sl.d))
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: Math.round(parent.height * 0.34)
                                        opacity: parent.open
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: "#00000000" }
                                            GradientStop { position: 1; color: "#cc000000" }
                                        }
                                    }
                                    Column {
                                        x: win.skew + 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 26
                                        width: parent.width - win.skew * 2 - 80
                                        spacing: 2
                                        opacity: parent.open
                                        BarText { width: parent.width; elide: Text.ElideRight; text: sl.modelData.name; font.pixelSize: 22; font.weight: Font.DemiBold; color: "white" }
                                        BarText { text: sl.modelData.path.split("/").slice(-3, -1).join("  ·  ") + (sl.isCurrent ? "   ·  current" : ""); font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.7) }
                                    }
                                    Rectangle {
                                        visible: sl.focused
                                        x: parent.width - win.skew - 56; y: parent.height - 70
                                        width: 40; height: 40; radius: 20
                                        color: starArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.4)
                                        BarIcon { anchors.centerIn: parent; name: "star"; size: 22; fill: sl.fav ? 1 : 0; color: sl.fav ? "#ffd166" : "white" }
                                        MouseArea { id: starArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperState.toggleFavourite(sl.modelData.path) }
                                    }
                                }
                                // Slices away from the focus are darker; the pointer only lightens one, it never moves the focus.
                                Rectangle { anchors.fill: parent; color: "black"; opacity: Math.min(1, Math.abs(sl.d)) * (hover.containsMouse && !win.moving ? 0.16 : 0.42) }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: Math.abs(sl.d) < 0.5 ? 3 : 1
                                    border.color: Math.abs(sl.d) < 0.5 ? BarStyle.accent : Qt.rgba(0, 0, 0, 0.6)
                                }
                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    function applyHere(): void {
                                        const p = sl.mapToItem(null, sl.width / 2, sl.height / 2)
                                        root.index = sl.index
                                        root.applyAt(sl.index, p.x / win.width, p.y / win.height)
                                    }
                                    onClicked: { if (sl.focused) applyHere(); else root.index = sl.index }
                                    onDoubleClicked: applyHere()
                                }
                            }
                            // The wallpaper in use.
                            Rectangle {
                                visible: sl.isCurrent && !sl.focused
                                x: parent.width / 2 - 4; y: parent.height - 18
                                width: 8; height: 8; radius: 4
                                color: BarStyle.accent
                            }
                        }
                    }
                }
            }

            // One line of help.
            BarText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(win.height * 0.5 + win.sliceH / 2 + win.height * 0.05)
                opacity: win.shown * 0.75
                text: root.view.length === 0 ? (WallpaperState.loading ? "Looking for wallpapers…" : "Nothing here") : (root.index + 1) + " / " + root.view.length + "      ←  →  browse      Enter  apply      F  favourite      S  sort      R  random      Tab  filters      Esc  close"
                font.pixelSize: 13
                color: "white"
            }
        }
    }
}
