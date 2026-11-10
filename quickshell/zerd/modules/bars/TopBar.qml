pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.services
import qs.modules.notificationPopup as INiRNotif
import "ilya/popouts"

// Floating top bar in three groups: workspaces and the focused window on the
// left, the clock/media island in the middle, the status capsule, tray and
// power on the right. Only the capsules take input.
//
// Autohide (default on): the bar slides away once the pointer has been off it
// for 400 ms and returns when the pointer touches the top edge. With autohide
// off and `reserve` on, the compositor gives it its own strip.
Scope {
    id: top

    // Pinned open by the `bar` IPC, independent of the pointer.
    property bool forced: false

    BarPopupHost {}
    TrayBase {}
    Sidebars {}
    Osd {}
    AppSwitcher {}
    ScreenshotTool {}
    WallpaperPicker {}
    SettingsWindow {}
    WidgetBoard {}
    BarEditor {}
    LazyLoader { active: (Config.options?.bars?.notifications?.engine ?? "inir") === "inir"; component: INiRNotif.NotificationPopup {} }
    NotifRuleSweep {}

    property string debug: ""

    IpcHandler {
        target: "focus"
        function toggle(): void { BarTools.toggleFocusMode() }
        function on(): void { BarTools.setFocusMode(true) }
        function off(): void { BarTools.setFocusMode(false) }
    }

    IpcHandler {
        target: "bar"
        function reveal(): void { top.forced = true }
        function hide(): void { top.forced = false }
        function toggle(): void { top.forced = !top.forced }
        // What the smart-hide rule currently sees, for checking the odd layouts.
        function status(): string { return top.debug }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            readonly property var options: Config.options?.bars?.top ?? ({})
            readonly property int barHeight: options.height ?? 34
            // pills: a capsule per group. strip: one full-width bar. floating: one rounded bar, inset from the edges.
            readonly property string look: options.look ?? "pills"
            readonly property int margin: look === "strip" ? 0 : (options.margin ?? 8)
            readonly property int sidePad: look === "strip" ? 14 : (look === "floating" ? margin + 14 : margin)
            // `autoHide` is the user's switch (always slide away). `smartHide` only does it in the odd layout where a
            // fullscreen window and an ordinary one share the workspace, so the bar would sit across the fullscreen one.
            readonly property bool userAutoHide: options.autoHide ?? false
            readonly property bool smartHide: options.smartHide ?? true
            readonly property var activeWorkspace: (NiriService.allWorkspaces ?? []).find(ws => ws.output === win.modelData.name && ws.is_active)
            readonly property var tiled: (NiriService.windows ?? []).filter(w => w.workspace_id === win.activeWorkspace?.id && !w.is_floating)
            // niri reports no fullscreen flag: a fullscreen window is exactly as large as the output. The odd layout
            // is a focused window narrow enough to leave room (a "half" window) with a fullscreen one in the
            // column beside it, so part of that fullscreen window is on screen under the bar. A wide focused window
            // (a maximised browser) hides its neighbours, and a lone fullscreen window already covers the bar.
            function isFull(w): bool {
                return (w.layout?.window_size?.[0] ?? 0) >= win.modelData.width - 2 && (w.layout?.window_size?.[1] ?? 0) >= win.modelData.height - 2
            }
            // The window flagged focused is kept current by NiriService; the workspace's `active_window_id` copy in
            // `allWorkspaces` is not, so it is only the fallback (focus on another output).
            readonly property var focusedTile: win.tiled.find(w => w.is_focused) ?? win.tiled.find(w => w.id === win.activeWorkspace?.active_window_id) ?? null
            readonly property bool mixedFullscreen: {
                const f = win.focusedTile
                if (!f || win.isFull(f) || (f.layout?.window_size?.[0] ?? 0) >= win.modelData.width - 40) return false
                const col = f.layout?.pos_in_scrolling_layout?.[0] ?? -1
                return win.tiled.some(w => win.isFull(w) && Math.abs((w.layout?.pos_in_scrolling_layout?.[0] ?? -99) - col) === 1)
            }
            Binding {
                target: top; property: "debug"
                value: JSON.stringify({ nsActive: NiriService.activeWindow?.id ?? null, flags: (NiriService.windows ?? []).filter(w => w.is_focused).map(w => w.id), mixed: win.mixedFullscreen, autoHide: win.autoHide, shown: win.shown, focused: win.focusedTile?.id ?? null, workspace: win.activeWorkspace?.id ?? null,
                    pointerOn: win.pointerOn, forced: top.forced, popup: GlobalStates.barPopup !== null, sidebar: BarState.sidebar,
                    tiled: win.tiled.map(w => [w.id, w.layout?.window_size, w.layout?.pos_in_scrolling_layout]) })
            }
            readonly property bool autoHide: userAutoHide || (smartHide && mixedFullscreen)
            // Windows only get the strip while the bar is there; hidden, they use the whole screen (no blank gap).
            readonly property bool reserve: !autoHide && (options.reserve ?? true)
            readonly property bool hiddenByState: NiriService.inOverview || GlobalStates.screenLocked

            // Revealed while the pointer is on the bar, a popup is open, or autohide is off.
            property bool pointerOn: false
            readonly property bool revealOnHover: options.revealOnHover ?? true
            readonly property bool shown: !autoHide || pointerOn || top.forced || GlobalStates.barPopup !== null || (BarState.sidebar !== "" && !win.mixedFullscreen)

            // Which block sits where (Settings > Bar). Order inside a side is fixed, so moving a block never scrambles the rest.
            readonly property var defaultSide: ({ left: "left", workspaces: "left", media: "left", timedate: "middle", sysmon: "right", cpuram: "right", info: "right", tray: "right", dnd: "right", wifi: "right", bt: "right", vol: "right", bat: "right", focus: "hidden", vis: "hidden" })
            readonly property var blockOrder: ["left", "workspaces", "media", "timedate", "sysmon", "cpuram", "info", "tray", "dnd", "wifi", "bt", "vol", "bat", "focus", "vis"]
            readonly property var layout: {
                const l = { left: [].concat(options.layoutLeft ?? []), middle: [].concat(options.layoutMiddle ?? []), right: [].concat(options.layoutRight ?? []), hidden: [].concat(options.layoutHidden ?? []) }
                const seen = {}
                for (const k in l) for (const id of l[k]) seen[id] = true
                for (const id of win.blockOrder) if (!seen[id]) l[win.defaultSide[id]].push(id)
                return l
            }
            function blocks(where: string): var {
                return win.layout[where].filter(id => win.blockOrder.includes(id))
            }
            // The status icons share one plate; every other block keeps its own.
            readonly property var plateOf: ({ cpuram: "res", info: "res", dnd: "conn", wifi: "conn", bt: "conn", vol: "snd", bat: "snd" })
            function runs(where: string): var {
                const out = []
                let lastKey = ""
                for (const id of win.blocks(where)) {
                    const key = win.plateOf[id] ?? ""
                    if (key !== "" && key === lastKey) out[out.length - 1].push(id)
                    else out.push([id])
                    lastKey = key
                }
                return out
            }
            readonly property Component chooser: Component {
                Item {
                    id: run
                    required property var modelData
                    // every status block sits on a plate like the ones on the left, even alone
                    readonly property bool grouped: (win.plateOf[modelData[0]] ?? "") !== ""
                    readonly property bool flat: win.look !== "pills"
                    width: runRow.width > 0 ? runRow.width + (grouped ? 8 : 0) : 0
                    height: win.barHeight
                    visible: width > 0
                    Rectangle {
                        visible: run.grouped && !run.flat
                        anchors.fill: parent
                        radius: 17
                        color: BarStyle.plateTint
                    }
                    Row {
                        id: runRow
                        x: run.grouped ? 4 : 0
                        spacing: run.grouped ? 2 : 0
                        Repeater {
                            model: run.modelData
                            delegate: Row {
                                id: cell
                                required property string modelData
                                spacing: 0
                                // a thin divider between the clusters of the status plate: resources | connectivity | sound and power
                                Item {
                                    visible: false
                                    width: visible ? 9 : 0
                                    height: win.barHeight
                                    Rectangle { anchors.centerIn: parent; width: 1; height: 16; radius: 0.5; color: Qt.rgba(BarStyle.text.r, BarStyle.text.g, BarStyle.text.b, 0.14) }
                                }
                                BarBlock {
                                    blockId: cell.modelData
                                    barHeight: win.barHeight
                                    screen: win.modelData
                                    revealed: win.shown
                                    flat: run.flat
                                    grouped: run.grouped
                                }
                            }
                        }
                    }
                }
            }

            screen: modelData
            color: "transparent"
            visible: !hiddenByState
            onHiddenByStateChanged: if (hiddenByState) BarState.closeAll()
            readonly property bool onScreen: win.shown && !win.hiddenByState
            onOnScreenChanged: BarState.barShown = onScreen
            Component.onCompleted: BarState.barShown = onScreen
            anchors { top: true; left: true; right: true }
            implicitHeight: barHeight + 2 * margin
            exclusionMode: reserve ? ExclusionMode.Auto : ExclusionMode.Ignore
            exclusiveZone: reserve ? barHeight + 2 * margin : 0
            WlrLayershell.namespace: "quickshell:zerd-bar-top"
            WlrLayershell.layer: WlrLayer.Top

            // Hidden: only a thin strip along the top edge listens, to bring the bar back.
            mask: Region {
                Region { item: edge }
                Region { item: left }
                Region { item: centre }
                Region { item: right }
            }

            Timer { id: hideDelay; interval: 600; onTriggered: win.pointerOn = false }
            function enter(): void { hideDelay.stop(); win.pointerOn = true }
            function leave(): void { hideDelay.restart() }

            Item {
                id: edge
                width: parent.width
                // Hidden: a thin trigger strip. Shown: the whole gap above the capsules, so a pointer still
                // resting on the screen edge counts as on the bar (else the bar slid out under it, the strip
                // came back, and it re-opened: shows for a moment, then goes).
                height: win.shown ? win.margin + 2 : 3
                // Resting on the edge, not just crossing it, brings the bar back.
                HoverHandler {
                    id: edgeHover
                    enabled: win.revealOnHover || win.shown
                    onHoveredChanged: if (win.shown && win.autoHide) { hovered ? win.enter() : win.leave() }
                }
                Timer { id: dwell; interval: 150; running: edgeHover.hovered && !win.shown; onTriggered: win.enter() }
            }

            Item {
                id: content
                width: parent.width
                height: parent.height
                y: win.shown ? 0 : -(win.barHeight + win.margin + 6)
                opacity: win.shown && !BarState.editingBar ? 1 : 0
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 110 } }

                // right-click anywhere on the bar that a block does not take itself: the bar menu
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: point => { BarState.sidebar = ""; GlobalStates.barPopup = { kind: "barmenu", x: Math.round(point.scenePosition.x), tab: "" } }
                }

                // the one plate behind everything in the strip and floating looks
                Rectangle {
                    visible: win.look !== "pills"
                    x: win.look === "strip" ? 0 : win.margin
                    y: win.look === "strip" ? 0 : win.margin
                    width: parent.width - 2 * x; height: win.barHeight
                    radius: win.look === "strip" ? 0 : height / 2
                    color: BarStyle.plateTint
                    border.width: win.look === "floating" ? 1 : 0
                    border.color: BarStyle.border
                    Rectangle { visible: win.look === "strip"; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: BarStyle.border }
                }
                Row {
                    id: left
                    x: win.sidePad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BarStyle.gap
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    Repeater { model: win.runs("left"); delegate: win.chooser }
                }
                Row {
                    id: centre
                    x: Math.max(left.x + left.width + 12, Math.min(Math.round((parent.width - width) / 2), right.x - width - 12))
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BarStyle.gap
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    Repeater { model: win.runs("middle"); delegate: win.chooser }
                }
                Row {
                    id: right
                    x: parent.width - width - win.sidePad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BarStyle.gap
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    Repeater { model: win.runs("right"); delegate: win.chooser }
                }
            }
        }
    }
}
