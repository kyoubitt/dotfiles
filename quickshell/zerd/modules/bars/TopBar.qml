pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.services

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
    Sidebars {}
    Osd {}
    AppSwitcher {}
    ScreenshotTool {}
    WallpaperPicker {}
    SettingsWindow {}
    WidgetBoard {}
    LazyLoader { active: (Config.options?.bars?.notifications?.engine ?? "rice") === "rice"; component: NotifPopups {} }

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
            readonly property int margin: options.margin ?? 8
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
                opacity: win.shown ? 1 : 0
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 110 } }

                Row {
                    id: left
                    x: win.margin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BarStyle.gap
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    WorkspacesFace { thickness: win.barHeight; output: win.modelData.name }
                    InfoFace { thickness: win.barHeight }
                    FocusFace { visible: win.options.showFocus ?? false; thickness: win.barHeight; maxTextWidth: 300 }
                }
                Row {
                    id: centre
                    x: Math.round((parent.width - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    IslandFace { thickness: win.barHeight }
                }
                Row {
                    id: right
                    x: parent.width - width - win.margin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: BarStyle.gap
                    HoverHandler { onHoveredChanged: hovered ? win.enter() : win.leave() }
                    ToolsFace { visible: win.options.showTools ?? true; thickness: win.barHeight }
                    KeyboardFace { thickness: win.barHeight }
                    StatusFace { thickness: win.barHeight; parentScreen: win.screen }
                    TrayFace { thickness: win.barHeight; window: win }
                    EndFace { thickness: win.barHeight }
                }
            }
        }
    }
}
