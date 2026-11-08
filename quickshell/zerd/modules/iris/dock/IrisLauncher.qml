pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Every installed app in one grid under a search capsule. Typing filters,
// arrows move, Enter launches, Escape closes. Right-click an app to pin or
// unpin it in the dock.
Scope {
    id: root

    readonly property bool open: GlobalStates.irisLauncherOpen
    function close(): void { GlobalStates.irisLauncherOpen = false }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === GlobalStates.focusedScreen?.name) ?? Quickshell.screens[0]
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea { anchors.fill: parent; onClicked: root.close() }

            Item {
                id: card
                readonly property real d: IrisStyle.density
                readonly property int rowHeight: Math.round(42 * d)
                readonly property int headerHeight: Math.round(28 * d)
                width: Math.round(380 * d)
                height: Math.min(win.height - Math.round(160 * d), Math.round(480 * d))
                x: Math.round((win.width - width) / 2)
                y: Math.round((win.height - height) / 2 - 40 * d)

                opacity: 0
                scale: 0.985
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120) } }
                Behavior on scale { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.OutCubic } }

                readonly property string query: input.text.trim()
                function keyOf(e): string { return String(e?.id ?? "").replace(/\.desktop$/, "") }

                // Flat model: headers and app rows, so one ListView scrolls both sections.
                readonly property var model: {
                    const q = card.query
                    const out = []
                    const pins = IrisDockOrder.pins.map(p => String(p).toLowerCase())
                    const hide = (Config.options?.iris?.launcher?.hidden ?? []).map(h => String(h).toLowerCase())
                    // Without a search the list leaves out the tools nobody opens; pinned apps always stay.
                    const found = q.length > 0 ? AppSearch.fuzzyQuery(q) : AppSearch.list.filter(a => {
                        const id = card.keyOf(a).toLowerCase(), name = String(a?.name ?? "").toLowerCase()
                        if (pins.includes(id)) return true
                        return !hide.some(h => id.includes(h) || name.includes(h))
                    })
                    const pinnedRows = []
                    for (const p of pins) {
                        const e = found.find(a => card.keyOf(a).toLowerCase() === p || card.keyOf(a).toLowerCase().split(".").pop() === p.split(".").pop())
                        if (e) pinnedRows.push(e)
                    }
                    if (pinnedRows.length > 0) {
                        out.push({ header: Translation.tr("Pinned") })
                        for (const e of pinnedRows) out.push({ entry: e, pinned: true })
                    }
                    const rest = found.filter(a => !pinnedRows.includes(a))
                    for (const e of rest) out.push({ entry: e, pinned: false })
                    // Typing also finds things to do, and sums.
                    if (q.length > 0) {
                        const sum = card.calc(q)
                        if (sum !== null) out.unshift({ header: Translation.tr("Calculator") }, { action: { title: "= " + sum, icon: "calculate", run: () => Quickshell.execDetached(["wl-copy", String(sum)]) } })
                        const lower = q.toLowerCase()
                        const acts = card.actions.filter(a => a.title.toLowerCase().includes(lower) || a.keys.some(k => k.startsWith(lower)))
                        if (acts.length > 0) {
                            out.push({ header: Translation.tr("Actions") })
                            for (const a of acts) out.push({ action: a })
                        }
                    }
                    return out
                }
                function esc(t: string): string { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
                // the name with the letters you typed in bold (a plain run of the query; fuzzy hits stay plain)
                function marked(name: string, q: string): string {
                    if (q.length === 0) return card.esc(name)
                    const i = name.toLowerCase().indexOf(q.toLowerCase())
                    if (i < 0) return card.esc(name)
                    return card.esc(name.slice(0, i)) + "<b>" + card.esc(name.slice(i, i + q.length)) + "</b>" + card.esc(name.slice(i + q.length))
                }
                readonly property int resultCount: card.model.filter(r => r.entry || r.action).length
                function calc(q: string): var {
                    if (!/^[0-9+\-*/().%\s^]+$/.test(q) || !/[0-9]/.test(q) || !/[+\-*/%^]/.test(q)) return null
                    try {
                        const v = Function("\"use strict\"; return (" + q.replace(/\^/g, "**") + ")")()
                        return (typeof v === "number" && isFinite(v)) ? Math.round(v * 1e9) / 1e9 : null
                    } catch (e) { return null }
                }
                function ipc(target: string, fn: string): void { Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", target, fn]) }
                readonly property var actions: [
                    { title: Translation.tr("Lock screen"), icon: "lock", keys: ["lock"], run: () => card.ipc("lockScreen", "lock") },
                    { title: Translation.tr("Sleep"), icon: "bedtime", keys: ["suspend", "sleep"], run: () => Quickshell.execDetached(["sh", "-c", "sleep 1; systemctl suspend"]) },
                    { title: Translation.tr("Restart"), icon: "restart_alt", keys: ["reboot", "restart"], run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                    { title: Translation.tr("Shut down"), icon: "power_settings_new", keys: ["poweroff", "shutdown"], run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
                    { title: Translation.tr("Log out"), icon: "logout", keys: ["logout", "exit"], run: () => Quickshell.execDetached(["niri", "msg", "action", "quit"]) },
                    { title: Translation.tr("Choose wallpaper"), icon: "wallpaper", keys: ["wallpaper", "background"], run: () => card.ipc("wallpaper", "toggle") },
                    { title: Translation.tr("Toggle desktop widgets"), icon: "widgets", keys: ["widgets"], run: () => card.ipc("widgets", "toggleAll") },
                    { title: Translation.tr("Toggle do not disturb"), icon: "notifications_off", keys: ["dnd", "silent"], run: () => Notifications.toggleSilent() },
                    { title: Translation.tr("Take a screenshot"), icon: "screenshot_region", keys: ["screenshot"], run: () => Quickshell.execDetached(["niri", "msg", "action", "screenshot"]) },
                    { title: Translation.tr("Show overview"), icon: "overview", keys: ["overview"], run: () => Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]) }
                ]
                function selectable(r): bool { return !!(r?.entry || r?.action) }
                function firstApp(): int { for (let i = 0; i < card.model.length; i++) if (card.selectable(card.model[i])) return i; return 0 }
                function step(from: int, dir: int): int {
                    for (let i = from + dir; i >= 0 && i < card.model.length; i += dir) if (card.selectable(card.model[i])) return i
                    return from
                }
                function launch(i: int): void {
                    const row = card.model[i]
                    if (row?.action) { root.close(); row.action.run(); return }
                    const e = row?.entry
                    if (!e) return
                    root.close()
                    AppSearch.launchEntry(e)
                }
                function movePin(i: int, dir: int): void {
                    const row = card.model[i]
                    if (!row?.pinned) return
                    const key = card.keyOf(row.entry).toLowerCase()
                    const pins = Array.from(IrisDockOrder.pins)
                    const at = pins.findIndex(p => String(p).toLowerCase() === key || String(p).toLowerCase().split(".").pop() === key.split(".").pop())
                    const to = at + dir
                    if (at < 0 || to < 0 || to >= pins.length) return
                    const moved = pins.splice(at, 1)[0]
                    pins.splice(to, 0, moved)
                    Config.setNestedValue(["iris", "dock", "pinnedApps"], pins)
                    list.currentIndex = card.step(i, dir) === i ? i : i + dir
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.round(18 * card.d)
                    antialiasing: true
                    color: IrisStyle.bodySurface
                    border.width: 1
                    border.color: IrisStyle.hairline
                }
                MouseArea { anchors.fill: parent }

                Rectangle {
                    id: bar
                    x: Math.round(8 * card.d)
                    y: Math.round(8 * card.d)
                    width: parent.width - 2 * x
                    height: Math.round(44 * card.d)
                    radius: height / 2
                    antialiasing: true
                    color: IrisStyle.surfaceHigh
                    border.width: 1
                    border.color: input.activeFocus ? IrisStyle.hairlineStrong : IrisStyle.hairline

                    MaterialSymbol {
                        x: Math.round(12 * card.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: 20
                        color: input.activeFocus ? IrisStyle.accent : IrisStyle.muted
                    }
                    IrisText {
                        visible: input.text.length === 0
                        x: Math.round(44 * card.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Search apps, files, commands")
                        color: IrisStyle.muted
                        font.pixelSize: 14
                    }
                    // result count, then a clear button once something is typed
                    IrisText {
                        visible: input.text.length > 0
                        anchors { right: parent.right; rightMargin: Math.round(44 * card.d); verticalCenter: parent.verticalCenter }
                        text: card.resultCount === 1 ? "1 result" : card.resultCount + " results"
                        color: IrisStyle.muted
                        font.pixelSize: 12
                    }
                    MaterialSymbol {
                        visible: input.text.length > 0
                        anchors { right: parent.right; rightMargin: Math.round(14 * card.d); verticalCenter: parent.verticalCenter }
                        text: "close"
                        iconSize: 18
                        color: clearHover.hovered ? IrisStyle.text : IrisStyle.muted
                        HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { input.text = ""; input.forceActiveFocus() } }
                    }
                    TextInput {
                        id: input
                        x: Math.round(44 * card.d)
                        width: parent.width - Math.round(44 * card.d) - Math.round(110 * card.d)
                        height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accent
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        font.hintingPreference: Font.PreferFullHinting
                        clip: true
                        focus: true
                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: list.currentIndex = card.firstApp()
                        Keys.onEscapePressed: root.close()
                        Keys.onReturnPressed: card.launch(list.currentIndex)
                        Keys.onEnterPressed: card.launch(list.currentIndex)
                        Keys.onDownPressed: list.currentIndex = card.step(list.currentIndex, 1)
                        Keys.onUpPressed: list.currentIndex = card.step(list.currentIndex, -1)
                        Keys.onPressed: event => {
                            if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                card.movePin(list.currentIndex, event.key === Qt.Key_Up ? -1 : 1)
                                event.accepted = true
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    x: Math.round(6 * card.d)
                    y: bar.y + bar.height + Math.round(6 * card.d)
                    width: parent.width - 2 * x
                    height: parent.height - y - Math.round(10 * card.d)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: card.model
                    currentIndex: card.firstApp()
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isHeader: modelData.header !== undefined
                        readonly property bool isAction: modelData.action !== undefined
                        readonly property bool current: ListView.isCurrentItem && !isHeader
                        readonly property string key: card.keyOf(modelData.entry)
                        readonly property bool pinned: modelData.pinned === true
                        width: list.width
                        height: isHeader ? card.headerHeight : card.rowHeight

                        IrisText {
                            visible: row.isHeader
                            x: Math.round(10 * card.d)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.round(4 * card.d)
                            text: row.modelData.header ?? ""
                            color: IrisStyle.subtext
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                            font.capitalization: Font.AllUppercase
                        }

                        Rectangle {
                            visible: !row.isHeader
                            anchors.fill: parent
                            anchors.topMargin: 1
                            anchors.bottomMargin: 1
                            radius: Math.round(10 * card.d)
                            antialiasing: true
                            color: tap.pressed ? IrisStyle.fillHover : row.current ? IrisStyle.tintFill(IrisStyle.accent) : hover.hovered ? IrisStyle.fillQuiet : "transparent"
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(100) } }
                        }
                        Row {
                            visible: !row.isHeader
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.round(10 * card.d)
                            spacing: Math.round(10 * card.d)
                            MaterialSymbol {
                                visible: row.isAction
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.action?.icon ?? ""
                                iconSize: Math.round(20 * card.d)
                                color: IrisStyle.accent
                            }
                            SmartAppIcon {
                                visible: !row.isAction
                                anchors.verticalCenter: parent.verticalCenter
                                icon: row.modelData.entry?.icon ?? ""
                                iconSize: Math.round(28 * card.d)
                            }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.StyledText
                                text: row.isAction ? card.esc(row.modelData.action.title) : card.marked(row.modelData.entry?.name ?? "", card.query)
                                font.pixelSize: 14
                            }
                        }
                        IrisText {
                            visible: row.current && !row.isHeader && !hover.hovered
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(14 * card.d)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u21B5"
                            color: IrisStyle.muted
                            font.pixelSize: 14
                            opacity: row.pinned ? 0 : 1
                        }
                        // Pin button: filled when pinned; otherwise shown only while hovering or selected.
                        MaterialSymbol {
                            visible: !row.isHeader && !row.isAction && (row.pinned || row.current || hover.hovered)
                            anchors.right: parent.right
                            anchors.rightMargin: Math.round(10 * card.d)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "keep"
                            fill: row.pinned ? 1 : 0
                            iconSize: 15
                            color: row.pinned ? IrisStyle.accent : (pinHover.hovered ? IrisStyle.text : IrisStyle.muted)
                            HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: IrisDockOrder.togglePin(row.key) }
                        }
                        HoverHandler { id: hover; enabled: !row.isHeader; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered && !row.isHeader) list.currentIndex = row.index }
                        TapHandler { id: tap; enabled: !row.isHeader; onTapped: card.launch(row.index) }
                        TapHandler { enabled: !row.isHeader; acceptedButtons: Qt.RightButton; onTapped: IrisDockOrder.togglePin(row.key) }
                    }
                }
            }
        }
    }
}
