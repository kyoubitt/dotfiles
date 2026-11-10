pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The window switcher: a card with a thumbnail for every open window, most recently used first.
//  - Alt+Tab (niri bind -> `ipc call switcher next`): each press moves along, releasing Alt switches.
//  - `ipc call switcher toggle` (the "Windows" buttons): stays open for the mouse. Hover selects,
//    click switches, wheel moves, middle click or the x closes a window, click outside leaves.
// Thumbnails are taken when the switcher opens (windows with a stale one only); until one arrives
// the card shows the app icon.
Scope {
    id: root

    property bool open: false
    property bool sticky: false
    property int index: 0
    property var entries: []

    readonly property bool previews: Config.options?.bars?.switcher?.previews ?? true
    readonly property int staleMs: 45000

    function iconFor(app: string): string { return AppSearch.lookupDesktopEntry(app)?.icon || AppSearch.guessIcon(app) }

    // The windows in most-recently-used order, snapshotted when the switcher opens.
    function snapshot(): var {
        const all = NiriService.windows ?? []
        const byId = {}
        for (const w of all) byId[w.id] = w
        const out = []
        for (const id of NiriService.mruWindowIds ?? []) if (byId[id]) { out.push(byId[id]); delete byId[id] }
        for (const w of all) if (byId[w.id]) out.push(w)
        return out
    }
    function refreshPreviews(list: var): void {
        if (!root.previews) return
        WindowPreviewService.initialize()
        const now = Date.now()
        const stale = list.filter(w => { const c = WindowPreviewService.previewCache[w.id]; return !c || now - c.timestamp > root.staleMs }).map(w => w.id)
        if (stale.length > 0) WindowPreviewService.captureIds(stale)
    }
    function begin(sticky: bool, start: int): bool {
        if (NiriService.inOverview || GlobalStates.screenLocked) return false
        const list = root.snapshot()
        if (list.length < 1 || (!sticky && list.length < 2)) return false
        BarState.closeAll()
        root.entries = list
        root.sticky = sticky
        root.index = Math.max(0, Math.min(list.length - 1, start < 0 ? list.length + start : start))
        root.revealed = true
        root.open = true
        root.refreshPreviews(list)
        return true
    }
    function step(by: int): void {
        const n = root.entries.length
        if (n > 0) root.index = (root.index + by + n) % n
        if (!root.sticky) idle.restart()
    }
    // Like niri's own switcher: the first press only selects the previous window and Alt's release lands on
    // it, so a quick tap switches with nothing on screen. The list fades in only if Alt is still held after a
    // moment, or at the second press. The surface is mapped (but invisible) from the first press, to see Alt let go.
    property bool revealed: false
    readonly property int revealMs: 150
    Timer { id: revealTimer; interval: root.revealMs; onTriggered: root.revealed = true }
    function show(by: int): void {
        if (root.open) { root.step(by); root.revealed = true; return }
        if (NiriService.inOverview || GlobalStates.screenLocked) return
        const list = root.snapshot()
        if (list.length < 2) return
        BarState.closeAll()
        root.entries = list
        root.sticky = false
        root.index = by > 0 ? 1 : list.length - 1
        root.revealed = false
        root.open = true
        revealTimer.restart()
        idle.restart()
        root.refreshPreviews(list)
    }
    function commit(): void {
        idle.stop(); revealTimer.stop()
        const w = root.entries[root.index]
        root.open = false
        root.revealed = false
        if (w) NiriService.focusWindow(w.id)
    }
    Connections { target: BarState; function onCloseOverlays() { root.cancel() } }
    function cancel(): void {
        idle.stop(); revealTimer.stop()
        root.open = false
        root.revealed = false
    }
    function closeWindow(i: int): void {
        const w = root.entries[i]
        if (!w) return
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(w.id)])
        const next = root.entries.filter((_, k) => k !== i)
        if (next.length === 0) { root.cancel(); return }
        root.entries = next
        root.index = Math.min(root.index, next.length - 1)
    }

    // If the release of Alt is never seen (a very quick tap), an untouched list still lands somewhere.
    Timer { id: idle; interval: 1800; onTriggered: root.commit() }

    // The Alt+Tab keys arrive through a FIFO (scripts/switcher-key.sh): a few milliseconds, where a
    // `qs ipc` call takes close to a tenth of a second. `exec cat` ends when a writer closes, then listens again.
    Process {
        id: keyPipe
        running: true
        command: ["sh", "-c", "f=\"$XDG_RUNTIME_DIR/zerd-switcher\"; pkill -f \"^cat $f\\$\" 2>/dev/null; [ -p \"$f\" ] || { rm -f \"$f\"; mkfifo -m 600 \"$f\"; }; exec cat \"$f\""]
        stdout: SplitParser {
            onRead: line => {
                const c = line.trim()
                if (c === "next") root.show(1)
                else if (c === "prev") root.show(-1)
                else if (c === "toggle") { if (root.open) root.cancel(); else root.begin(true, 1) }
            }
        }
        onExited: reopen.start()
    }
    Timer { id: reopen; interval: 2; onTriggered: keyPipe.running = true }

    IpcHandler {
        target: "switcher"
        function next(): void { root.show(1) }
        function prev(): void { root.show(-1) }
        function toggle(): void { if (root.open) root.cancel(); else root.begin(true, 1) }
        function commit(): void { if (root.open) root.commit() }
        function cancel(): void { root.cancel() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool mine: Quickshell.screens.length < 2 || win.modelData.name === NiriService.currentOutput

            screen: modelData
            visible: root.open && win.mine
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-switcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: win.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.revealed ? 0.22 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            MouseArea { anchors.fill: parent; enabled: root.revealed; onClicked: root.cancel() }

            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
                    else if (event.key === Qt.Key_Tab) { root.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true }
                    else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) { root.step(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Right) { root.step(1); event.accepted = true }
                    else if (event.key === Qt.Key_Delete || event.key === Qt.Key_W) { root.closeWindow(root.index); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.commit(); event.accepted = true }
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt && !event.isAutoRepeat && !root.sticky) { root.commit(); event.accepted = true }
                }
            }
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            // Plasma's plain switcher: a flat strip, thumbnails with the app icon and title under each,
            // and a soft highlight behind the selected one.
            Rectangle {
                id: panel
                readonly property int cardW: 300
                readonly property int cardH: 224
                readonly property int gap: 10
                readonly property int pad: 18
                width: Math.min(win.width - 100, root.entries.length * (cardW + gap) - gap + 2 * pad)
                height: cardH + 2 * pad
                x: Math.round((win.width - width) / 2)
                y: Math.round((win.height - height) / 2 - 20)
                radius: 30
                color: BarStyle.surface
                border.width: 1
                border.color: BarStyle.border
                opacity: root.revealed ? 1 : 0
                scale: root.revealed ? 1 : 0.97
                transformOrigin: Item.Center
                Behavior on opacity { NumberAnimation { duration: 110 } }
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1) }

                ListView {
                    id: list
                    x: panel.pad; y: panel.pad
                    width: parent.width - 2 * panel.pad
                    height: panel.cardH
                    orientation: ListView.Horizontal
                    spacing: panel.gap
                    clip: true
                    interactive: false
                    model: root.entries
                    currentIndex: root.index
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 150
                    highlightMoveVelocity: -1
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    // One highlight that slides from card to card.
                    highlight: Rectangle {
                        radius: 23
                        color: Qt.rgba(BarStyle.accent.r, BarStyle.accent.g, BarStyle.accent.b, 0.22)
                    }

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool picked: root.index === index
                        readonly property string preview: root.previews ? (WindowPreviewService.getPreviewUrl(modelData.id) ?? "") : ""
                        // Cards arrive one after another.
                        property bool arrived: false
                        Timer { running: true; interval: Math.min(card.index, 8) * 20; onTriggered: card.arrived = true }

                        width: panel.cardW
                        height: list.height
                        opacity: arrived ? (picked || cardArea.containsMouse ? 1 : 0.78) : 0
                        Behavior on opacity { NumberAnimation { duration: 110 } }

                        // Thumbnail, or the app icon until there is one.
                        ClippingRectangle {
                            x: 10; y: 10
                            width: parent.width - 20; height: parent.height - 56
                            radius: 12
                            color: BarStyle.plate
                            SmartAppIcon {
                                anchors.centerIn: parent
                                icon: root.iconFor(card.modelData.app_id ?? "")
                                iconSize: 72
                                opacity: shot.status === Image.Ready ? 0 : 0.9
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Image {
                                id: shot
                                anchors.fill: parent
                                source: card.preview
                                sourceSize.width: 600
                                fillMode: Image.PreserveAspectCrop
                                verticalAlignment: Image.AlignTop
                                asynchronous: true
                                cache: false
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                        // The app and the window's name, centred under the thumbnail.
                        Row {
                            y: parent.height - 36
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 7
                            SmartAppIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.iconFor(card.modelData.app_id ?? ""); iconSize: 22 }
                            BarText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, card.width - 20 - 27 - 6)
                                elide: Text.ElideRight
                                text: card.modelData.title || card.modelData.app_id || "Window"
                                font.pixelSize: 13
                            }
                        }
                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            // Moving the pointer selects; a pointer that merely sits where the switcher opened does not.
                            onPositionChanged: if (root.index !== card.index) root.index = card.index
                            onClicked: mouse => { if (mouse.button === Qt.LeftButton) { root.index = card.index; root.commit() } }
                            onPressed: mouse => { if (mouse.button === Qt.MiddleButton) root.closeWindow(card.index) }
                            onWheel: wheel => root.step(wheel.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }
            }
        }
    }
}
