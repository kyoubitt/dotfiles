pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services

// Clock/calendar/weather/system/media widget panel - a full-height column
// docked to the right edge of the screen.
//
// WlrLayer.Bottom (the literal "below apps" layer) doesn't actually work
// here: modules/waffle/background/WaffleBackground.qml (the real wallpaper
// renderer, not just the awww-daemon fallback) is ALSO Bottom layer and
// full-screen, and empirically wins the undefined same-layer stacking order
// against this panel - the wallpaper rendered on top of the widgets
// instead of under them. wlr-layer-shell has no finer-grained ordering
// within a single layer to force this panel above that one.
//
// So instead: Top layer (reliably above the Bottom-layer wallpaper, no
// ordering ambiguity - and confirmed not to have the alpha-blending bug
// WlrLayer.Bottom has on this system) plus explicit visibility logic that
// hides the panel only when a window large enough to actually reach this
// corner is open on the current workspace (see windowCoversCorner below),
// the same idea WaffleBackground.qml itself already uses (hasFullscreenWindow)
// to fake "below apps" behavior without relying on layer z-order at all.
Variants {
    id: root
    model: Quickshell.screens

    // Declared here (a direct child of the file's root object) rather
    // than nested inside a deeper layout - inline `component` blocks must
    // be direct children of the root.
    component Card: Rectangle {
        id: card
        default property alias content: inner.children
        // Stretch to take whatever vertical space the column has left
        // over, with the content following the card's full height.
        property bool stretch: false
        Layout.fillWidth: true
        Layout.fillHeight: card.stretch
        implicitHeight: inner.implicitHeight + 24
        radius: 16
        antialiasing: true
        color: WallustTheme.bgCard
        border.width: 1
        border.color: WallustTheme.cardBorder

        Item {
            id: inner
            x: 12
            y: 12
            width: card.width - 24
            height: card.stretch ? card.height - 24 : implicitHeight
            implicitHeight: childrenRect.height
        }
    }

    PanelWindow {
        id: panelWindow
        required property var modelData
        screen: modelData

        // Full height of the screen's right side - the translucent cards
        // below span all of it.
        anchors {
            top: true
            bottom: true
            right: true
        }
        implicitWidth: 340

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:wWidgetsPanel"
        exclusiveZone: 0

        // Hides only when a window is actually sitting over this corner.
        // niri's `tile_pos_in_workspace_view` (true on-screen X) is always
        // null here, so true overlap can't be computed exactly - the best
        // available signal is the scrolling-layout column data:
        //  - a window nearly as wide as the output covers the corner
        //  - on a workspace with several columns, the rightmost column is
        //    the one pinned against the right edge once scrolled to the end
        // Anything else (a window tucked in the left/middle of the screen)
        // leaves the corner clear, so the panel stays up.
        //
        // Recomputed explicitly off NiriService.windows/workspaces changing
        // (same pattern TaskbarApps.qml uses for its own apps list) rather
        // than left as a live `readonly property` binding - this body reads
        // both of those on every single window-layout event (which fire
        // constantly during drags/resizes), and QML flagged it as a binding
        // loop under that churn. There was no real cycle to find by reading
        // the code, but an imperative recompute triggered from Connections
        // isn't tracked as a binding at all, so the detector simply can't
        // flag it either way - strictly safer regardless of what the
        // original trigger was.
        property bool windowCoversCorner: false
        function _recomputeWindowCoversCorner() {
            try {
                if (!(CompositorService.isNiri && NiriService.windows && NiriService.workspaces)) {
                    panelWindow.windowCoversCorner = false
                    return
                }
                const allWs = Object.values(NiriService.workspaces)
                if (!allWs || allWs.length === 0) {
                    panelWindow.windowCoversCorner = false
                    return
                }
                const currentNumber = NiriService.getCurrentWorkspaceNumber()
                const currentWs = allWs.find(ws => ws.idx === currentNumber)
                if (!currentWs) {
                    panelWindow.windowCoversCorner = false
                    return
                }
                const wins = NiriService.windows.filter(w => w.workspace_id === currentWs.id && w.layout)
                if (wins.length === 0) {
                    panelWindow.windowCoversCorner = false
                    return
                }
                const outputWidth = panelWindow.screen.width
                const colOf = w => w.layout.pos_in_scrolling_layout?.[0] ?? 1
                const maxCol = Math.max(...wins.map(colOf))
                panelWindow.windowCoversCorner = wins.some(w => {
                    const tileWidth = w.layout.tile_size?.[0] ?? 0
                    if (tileWidth >= outputWidth - 400) return true
                    return maxCol > 1 && colOf(w) === maxCol
                })
            } catch (e) {
                panelWindow.windowCoversCorner = false
            }
        }
        Component.onCompleted: panelWindow._recomputeWindowCoversCorner()
        Connections {
            target: NiriService
            function onWindowsChanged() { panelWindow._recomputeWindowCoversCorner() }
            function onWorkspacesChanged() { panelWindow._recomputeWindowCoversCorner() }
        }

        // NiriService.inOverview - same property WaffleBackground.qml
        // already uses to hide itself during the overview - the widget
        // cards floating over the workspace thumbnails there looked wrong
        // and aren't meaningful in that context anyway.
        // WidgetsState.hidden is flipped by the widgetsPanel IPC handler
        // (niri keybind, Mod+Shift+W) - hides it outright regardless of
        // windows.
        visible: !WidgetsState.hidden && !panelWindow.windowCoversCorner && !NiriService.inOverview

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Card { WClockCard { anchors.horizontalCenter: parent.horizontalCenter } }
            Card { WCalendarCard { anchors.left: parent.left } }
            Card { WWeatherCard { anchors.left: parent.left } }
            Card { WSystemCard { anchors.left: parent.left } }
            // Stretches to fill the rest of the column's height, so the
            // full-height panel doesn't trail off into empty space below
            // the last card.
            Card { stretch: true; WMediaCard { width: parent.width; height: parent.height } }
        }
    }
}
