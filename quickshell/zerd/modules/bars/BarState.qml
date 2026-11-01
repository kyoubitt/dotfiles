pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.modules.common

// Small shared state for the bar modules. A side panel and a bar popup are never open together.
Singleton {
    // "", "left" or "right": which side panel is open.
    property string sidebar: ""
    // Whether the top bar is on screen right now, so banners sit under it or up at the edge.
    property bool barShown: true
    // The one hover label allowed on screen (see BarTip).
    property string tipOwner: ""
    // A click that opens a panel or popup takes the pointer away from the bar without a "leave",
    // so a label can stay claimed by the last item clicked. Any such change drops the label.
    onSidebarChanged: tipOwner = ""
    readonly property var openPopup: GlobalStates.barPopup
    onOpenPopupChanged: tipOwner = ""
    // Opened by a click or a command: stays until dismissed. Opened by the screen edge: leaves with the pointer.
    property bool pinned: true
    // How far the open side panel has grown (0 to 1); sections arrive in turn as it passes their share.
    property real panelEnter: 1
    // The widget board (arrange desktop cards) is open.
    property bool board: false
    // Bumped to ask the quick panel's clipboard section to take the cursor (Mod+V).
    property int clipboardRequest: 0
    function openClipboard(): void {
        GlobalStates.barPopup = null
        pinned = true
        sidebar = "left"
        const open = Config.options?.bars?.sidebars?.expanded ?? []
        if (!open.includes("clipboard")) Config.options.bars.sidebars.expanded = open.concat(["clipboard"])
        clipboardRequest++
    }
    function toggleClipboard(): void { if (sidebar === "left") closeAll(); else openClipboard() }
    function openBoard(): void { closeAll(); board = true }
    function toggleBoard(): void { if (board) board = false; else openBoard() }
    function toggleSidebar(side: string): void {
        GlobalStates.barPopup = null
        pinned = true
        sidebar = sidebar === side ? "" : side
    }
    function peek(side: string): void {
        GlobalStates.barPopup = null
        if (sidebar === "") { pinned = false; sidebar = side }
    }
    // Asked of every full-screen overlay (wallpaper picker, switcher, ...) that holds the keyboard, by whatever
    // is about to take the screen over (the screenshot tool).
    signal closeOverlays()
    function closeAll(): void {
        sidebar = ""
        GlobalStates.barPopup = null
    }
}
