pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// Two slide-in panels. Left: the quick panel (toggles, sliders, player, tasks, stats).
// Right: collapsible sections for calendar, weather, notifications and system.
// Open from the bar buttons or with `ipc call sidebars toggle left|right`: that pins the panel
// (click outside or Escape closes it). Resting the pointer on a screen edge only peeks: no click
// catcher, the panel leaves with the pointer, and touching anything inside pins it.
Scope {
    id: root

    readonly property var options: Config.options?.bars?.sidebars ?? ({})
    // The movable sections under the fixed part of the quick panel, in the saved order.
    readonly property var leftNames: ["clipboard", "shots", "notifrules", "battery", "tasks"]
    readonly property var leftOrder: {
        const saved = Config.options?.bars?.sidebars?.leftOrder ?? []
        return saved.filter(n => root.leftNames.includes(n)).concat(root.leftNames.filter(n => !saved.includes(n)))
    }
    readonly property bool edgeHover: options.edgeHover ?? true
    readonly property string edgeSide: options.edgeSide ?? "both"

    // Everything tucks away when the overview opens or the screen locks.
    readonly property bool overview: NiriService.inOverview
    readonly property bool locked: GlobalStates.screenLocked
    onOverviewChanged: if (overview) BarState.closeAll()
    onLockedChanged: if (locked) BarState.closeAll()

    // After a panel closes, the edge strips stay quiet for a moment, so a pointer still resting
    // on the edge does not reopen it straight away.
    property bool cooling: false
    Connections {
        target: BarState
        function onSidebarChanged(): void { if (BarState.sidebar === "") { root.cooling = true; cool.restart() } }
    }
    Timer { id: cool; interval: 600; onTriggered: root.cooling = false }

    IpcHandler {
        target: "sidebars"
        function toggle(side: string): void { BarState.toggleSidebar(side === "right" ? "right" : "left") }
        function close(): void { BarState.closeAll() }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { BarState.toggleClipboard() }
        function open(): void { BarState.openClipboard() }
        function close(): void { BarState.closeAll() }
    }

    // ---- Screen-edge triggers: a thin strip that opens the panel once the pointer rests on it.
    Variants {
        model: Quickshell.screens

        Scope {
            id: edges
            required property var modelData
            // Only a window as big as the whole output (a game, a fullscreen video) switches the edges off; a
            // maximised or wide tiled window does not.
            readonly property bool trulyFull: {
                const w = NiriService.activeWindow?.layout?.window_size
                return !!w && w[0] >= modelData.width - 2 && w[1] >= modelData.height - 2
            }
            readonly property bool usable: root.edgeHover && BarState.sidebar === "" && !root.cooling && !NiriService.inOverview
                && !GlobalStates.screenLocked && !edges.trulyFull

            // The left edge opens the panel only when no window is there to cover it (an empty workspace, or only
            // floating windows): niri does not say where tiles are, and with a window open the pointer lives at that
            // edge. The right edge always works, as in iNiR. The bar button, Mod+V and IPC open either panel anyway.
            function free(side: string): bool {
                if (side === "right") return true
                const ws = (NiriService.allWorkspaces ?? []).find(w => w.output === modelData.name && w.is_active)
                return !(NiriService.windows ?? []).some(w => w.workspace_id === ws?.id && !w.is_floating)
            }

            // An invisible zone on the middle of the edge (not the corners or a browser's scrollbar), as in iNiR:
            // nothing is drawn, the panel growing out of the edge is the feedback.
            component Strip: PanelWindow {
                id: strip
                required property string side
                screen: edges.modelData
                visible: edges.usable && edges.free(side) && (root.edgeSide === "both" || root.edgeSide === side)
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                implicitWidth: 2
                implicitHeight: Math.round((screen?.height ?? 1080) * 0.6)
                anchors { top: true; left: side === "left"; right: side === "right" }
                margins.top: Math.round(((screen?.height ?? 1080) - implicitHeight) / 2)
                WlrLayershell.namespace: "quickshell:zerd-sidebar-edge"
                WlrLayershell.layer: WlrLayer.Top
                // Opens only for a pointer that moved onto the edge. A window sliding or closing under a
                // pointer that is just sitting there also "enters" the strip, and must not open the panel.
                property bool moved: false
                readonly property bool active: edgeArea.containsMouse && strip.moved
                MouseArea {
                    id: edgeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: strip.moved = true
                    onExited: strip.moved = false
                }
                Timer { interval: 140; running: strip.active && strip.visible; onTriggered: BarState.peek(strip.side) }
            }
            Strip { side: "left" }
            Strip { side: "right" }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            // What is asked for (`wanted`) and what is on screen (`displaySide`, `on`) are kept apart, so going
            // from one side to the other slides the first panel out, then the second in, rather than the panel
            // flying across the screen with its content swapping under it.
            readonly property string wanted: BarState.sidebar
            property string displaySide: ""
            property bool on: false
            property bool swapping: false
            readonly property bool onRight: displaySide === "right"
            // How far the panel has grown out of its screen edge (iNiR's morph): 0 = a thin band on the edge, 1 = open.
            property real progress: 0
            onOnChanged: progress = on ? 1 : 0
            Behavior on progress { NumberAnimation { id: slide; duration: win.on ? 150 : 100; easing.type: win.on ? Easing.OutCubic : Easing.InCubic } }
            Binding { target: BarState; property: "panelEnter"; value: win.progress }
            onWantedChanged: {
                if (wanted === "") { on = false; swapTimer.stop(); return }
                if (displaySide === "" || displaySide === wanted) { displaySide = wanted; on = true; return }
                on = false
                swapTimer.restart()
            }
            Timer {
                id: swapTimer
                interval: 120
                onTriggered: { win.swapping = true; win.displaySide = win.wanted; settle.start() }
            }
            Timer { id: settle; interval: 30; onTriggered: { win.swapping = false; win.on = win.wanted !== "" } }

            screen: modelData
            visible: !NiriService.inOverview && (wanted !== "" || on || win.progress > 0.001)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-sidebar"
            WlrLayershell.layer: WlrLayer.Overlay
            // Pinned panels take the keyboard so Escape works at once; a peek never steals it.
            WlrLayershell.keyboardFocus: win.wanted === "" ? WlrKeyboardFocus.None : (BarState.pinned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
            // Only a pinned panel catches clicks outside itself; a peek leaves the apps clickable.
            readonly property bool catching: win.wanted !== "" && BarState.pinned
            mask: Region { item: win.catching ? backdrop : panel; Region { item: hold } }

            // Starts below the bar, so the bar stays clickable while the panel is open.
            MouseArea { id: backdrop; y: 50; width: parent.width; height: parent.height - 50; onClicked: BarState.closeAll() }
            Item { focus: true; Keys.onEscapePressed: BarState.closeAll() }

            Item {
                id: hold
                x: win.onRight ? panel.x : 0
                y: panel.y
                width: Math.max(0, win.onRight ? win.width - panel.x : panel.x + panel.width)
                height: panel.height
                HoverHandler { id: holdHover }
            }

            Rectangle {
                id: panel
                readonly property int margin: 10
                readonly property int fullWidth: 380
                readonly property real screenW: win.screen?.width ?? 1920
                readonly property real p: win.progress
                visible: p > 0.001
                clip: true
                // Grows out of the edge: a thin band at the screen edge becomes the panel.
                width: 3 + (fullWidth - 3) * p
                y: 58
                // The whole side, under the bar; the content scrolls when it has to.
                height: win.height - 58 - margin
                x: win.onRight ? screenW - width - margin * p : margin * p
                radius: 2 + 22 * p
                antialiasing: true
                color: BarStyle.surface
                border.width: 1
                border.color: BarStyle.border
                MouseArea { anchors.fill: parent }

                // A panel opened by the screen edge leaves when the pointer does. The gap between the
                // panel and the screen edge counts as inside, or the panel would close under a pointer
                // still resting on the edge and the edge strip would open it again (a flicker).
                HoverHandler { id: panelHover }
                Timer { interval: 280; running: win.on && !BarState.pinned && !panelHover.hovered && !holdHover.hovered; onTriggered: BarState.closeAll() }

                // The content keeps its full size and is uncovered as the body grows, fading in from a third of the way.
                Item {
                    id: inner
                    width: panel.fullWidth
                    height: parent.height
                    x: win.onRight ? panel.width - panel.fullWidth : 0
                    opacity: Math.max(0, Math.min(1, (panel.p - 0.3) / 0.7))
                    scale: 0.97 + 0.03 * panel.p
                    transformOrigin: win.onRight ? Item.Right : Item.Left

                // Title, pin (keeps it open) and close.
                Item {
                    id: head
                    x: 20; y: 10; width: parent.width - 40; height: 32
                    BarText { anchors.verticalCenter: parent.verticalCenter; text: win.onRight ? "Sections" : "Quick panel"; color: BarStyle.subtext; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        component HeadBtn: Rectangle {
                            id: hb
                            property string icon
                            property bool lit: false
                            property string tip
                            signal tapped()
                            width: 32; height: 32; radius: 16
                            color: hbArea.pressed ? BarStyle.border : (hb.lit ? BarStyle.plateHover : (hbHv.hovered ? BarStyle.plateHover : "transparent"))
                            Behavior on color { ColorAnimation { duration: 100 } }
                            BarIcon { anchors.centerIn: parent; name: hb.icon; size: 17; fill: hb.lit ? 1 : 0; color: hb.lit ? BarStyle.accent : BarStyle.subtext }
                            MouseArea { id: hbArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: hb.tapped() }
                            HoverHandler { id: hbHv }
                            BarTip { text: hb.tip; external: hbHv.hovered }
                        }
                        HeadBtn { icon: "push_pin"; lit: BarState.pinned; tip: BarState.pinned ? "Pinned: stays until closed" : "Pin open"; onTapped: BarState.pinned = !BarState.pinned }
                        HeadBtn { icon: "close"; tip: "Close"; onTapped: BarState.closeAll() }
                    }
                }

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.topMargin: 52
                    anchors.bottomMargin: 8
                    contentHeight: column.implicitHeight + 24
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: column
                        width: parent.width
                        spacing: 16

                        // ---- Left: quick panel
                        Column {
                            visible: !win.onRight
                            width: parent.width
                            spacing: 16
                            QuickHeader { width: parent.width }
                            QuickToggles { width: parent.width }
                            QuickSliders { width: parent.width; screen: win.screen }
                            QuickMedia { width: parent.width }
                            QuickRings { width: parent.width }
                            Component {
                                id: cClipboard
                                AccordionSection {
                                    width: stack.width
                                    name: "clipboard"; icon: "content_paste"; title: "Clipboard"
                                    summary: "Search, pin, images"
                                    ClipboardSection { width: parent.width }
                                }
                            }
                            Component {
                                id: cShots
                                AccordionSection {
                                    width: stack.width
                                    name: "shots"; icon: "screenshot_region"; title: "Screenshots"
                                    summary: "Latest shots"
                                    ScreenshotsSection { width: parent.width }
                                }
                            }
                            Component {
                                id: cRules
                                AccordionSection {
                                    width: stack.width
                                    name: "notifrules"; icon: "notifications_paused"; title: "Notification rules"
                                    summary: NotifRules.raw.length + " custom"
                                    NotifRulesSection { width: parent.width }
                                }
                            }
                            Component {
                                id: cBattery
                                AccordionSection {
                                    width: stack.width
                                    name: "battery"; icon: "battery_full"; title: "Battery"
                                    summary: Math.round(Battery.percentage * 100) + "%" + (Battery.isCharging ? "  ·  charging" : "")
                                    BatteryPopup { width: parent.width }
                                }
                            }
                            Component {
                                id: cTasks
                                AccordionSection {
                                    width: stack.width
                                    name: "tasks"; icon: "checklist"; title: "Tasks"
                                    summary: Todo.list.filter(t => !t.done).length + " to do"
                                    TasksSection { width: parent.width }
                                }
                            }
                            SectionStack {
                                id: stack
                                width: parent.width
                                names: root.leftNames
                                order: root.leftOrder
                                hidden: Battery.available ? [] : ["battery"]
                                comps: ({ clipboard: cClipboard, shots: cShots, notifrules: cRules, battery: cBattery, tasks: cTasks })
                                onMoved: list => Config.options.bars.sidebars.leftOrder = list
                            }
                        }

                        // ---- Right: sections
                        RightSections {
                            visible: win.onRight
                            width: parent.width
                        }
                    }
                }

                // Fade and a slim scrollbar so cut-off content reads as "scrolls", not "cropped".
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 1; rightMargin: 1; bottomMargin: 1 }
                    height: 36
                    radius: panel.radius
                    opacity: flick.contentY + flick.height < flick.contentHeight - 4 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(BarStyle.surface.r, BarStyle.surface.g, BarStyle.surface.b, 0) }
                        GradientStop { position: 1; color: BarStyle.surface }
                    }
                }
                Rectangle {
                    visible: flick.contentHeight > flick.height + 2
                    x: parent.width - 8; width: 3; radius: 1.5
                    y: 52 + (flick.height - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                    height: Math.max(24, flick.height * flick.height / flick.contentHeight)
                    color: BarStyle.border
                }

                // Any press inside pins a peeked panel. It refuses the press, so the control under it still gets it.
                MouseArea {
                    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom }
                    z: 100
                    onPressed: mouse => { if (!BarState.pinned) BarState.pinned = true; mouse.accepted = false }
                }
                }
            }
        }
    }
}
