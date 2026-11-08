pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import "ilya" as Ilya

// One popup at a time under the top bar (GlobalStates.barPopup): calendar,
// media, volume, brightness, network, battery and system details. Click
// outside or Escape closes it.
Scope {
    id: root

    readonly property var popup: GlobalStates.barPopup
    property bool wasOpen: false

    readonly property bool overview: NiriService.inOverview
    onOverviewChanged: if (overview) GlobalStates.barPopup = null

    // `ipc call barpopup open <kind>` opens a popup centred on the screen's top; `close` closes it.
    IpcHandler {
        target: "barpopup"
        function open(kind: string): void { BarState.sidebar = ""; GlobalStates.barPopup = { kind: kind, x: 960 } }
        function close(): void { GlobalStates.barPopup = null }

    }

    // The copied popups: file, size, and which screen corner they sit in (his WindowRegistry layout).
    readonly property var copied: ({
        volume: { src: Qt.resolvedUrl("ilya/volume/VolumePopup.qml"), w: 410, h: 580, at: "right", m: 5 },
        calendar: { src: Qt.resolvedUrl("ilya/calendar/CalendarPopup.qml"), w: 1320, h: 470, at: "center", m: 0 },
        weather: { src: Qt.resolvedUrl("ilya/calendar/CalendarPopup.qml"), w: 1320, h: 470, at: "center", m: 0 },
        network: { src: Qt.resolvedUrl("ilya/network/NetworkPopup.qml"), w: 720, h: 600, at: "right", m: 4 },
        media: { src: Qt.resolvedUrl("ilya/media/MusicPopup.qml"), w: 625, h: 565, at: "left", m: 5 },
        battery: { src: Qt.resolvedUrl("ilya/syspanel/SystemPanel.qml"), w: 440, h: 0, at: "right", m: 5, fit: true },
        system: { src: Qt.resolvedUrl("ilya/syspanel/SystemPanel.qml"), w: 440, h: 0, at: "right", m: 5, fit: true },
        brightness: { src: Qt.resolvedUrl("ilya/syspanel/SystemPanel.qml"), w: 440, h: 0, at: "right", m: 5, fit: true },
        sysmon: { src: Qt.resolvedUrl("ilya/sysmon/SystemMonitorPopup.qml"), w: 520, h: 0, at: "right", m: 5, fit: true },
        clock: { src: Qt.resolvedUrl("ilya/calendar/CalendarPopup.qml"), w: 1320, h: 470, at: "center", m: 0 }
    })
    readonly property var spec: copied[popup?.kind ?? ""] ?? null
    function close(): void { GlobalStates.barPopup = null }

    // Created once and shown/hidden, so a click never waits for the window to be built.
    Item {
        PanelWindow {
            id: win
            visible: (root.popup !== null || pl.active) && !NiriService.inOverview && !GlobalStates.screenLocked
            screen: Quickshell.screens.find(s => s.name === GlobalStates.focusedScreen?.name) ?? Quickshell.screens[0]
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            WlrLayershell.namespace: "quickshell:zerd-bar-popup"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // The bar strip stays clickable, so another bar item can be pressed while a popup is open.
            mask: Region { item: backdrop }
            MouseArea { id: backdrop; y: 50; width: parent.width; height: parent.height - 50; onClicked: root.close() }
            Item { focus: true; Keys.onEscapePressed: root.close() }

            Shortcut { sequence: "Escape"; enabled: root.popup !== null; onActivated: root.close() }

            // A popup copied from serpantinum: created when asked for, plays its own enter and leave.
            Item {
                id: stage
                visible: pl.active
                width: root.spec?.w ?? 0
                height: root.spec?.fit ? Math.min(win.height - 64, Math.max(300, pl.item?.contentHeight ?? 640)) : (root.spec?.full ? win.height : (root.spec?.h ?? 0))
                x: root.spec?.at === "left" ? (root.spec?.m ?? 0) : root.spec?.at === "center" ? Math.round((win.width - width) / 2) : win.width - width - (root.spec?.m ?? 0)
                y: root.spec?.full ? 0 : 52
                MouseArea { anchors.fill: parent }
                Loader {
                    id: pl
                    anchors.fill: parent
                    active: false
                    // TEMP DEBUG: what the loader and the stage look like on every open
                    onStatusChanged: console.log("POPUPDBG loader", String(source).split("/").pop(), "status", status === Loader.Ready ? "ready" : (status === Loader.Error ? "ERROR" : (status === Loader.Loading ? "loading" : "null")))
                    onLoaded: { console.log("POPUPDBG stage", root.popup?.kind, "x", stage.x, "y", stage.y, "w", stage.width, "h", stage.height, "win visible", win.visible, "win", win.width, "x", win.height, "screen", win.screen ? win.screen.name : "none", "item", item.width, "x", item.height); item.visible = true; if (root.popup?.tab && item.gotoTab) item.gotoTab(root.popup.tab) }
                }
            }
            Connections {
                target: root
                function onPopupChanged() {
                    console.log("POPUPDBG changed", root.popup?.kind ?? "closed", root.spec ? String(root.spec.src).split("/").pop() : "no-spec") /* TEMP DEBUG */
                    if (root.popup && !root.wasOpen) { console.log("SFXDBG", root.popup.kind, "open") /* TEMP DEBUG */; Ilya.Sounds.popupOpened() }
                    else if (!root.popup && root.wasOpen) { console.log("SFXDBG", "popup", "close") /* TEMP DEBUG */; Ilya.Sounds.popupClosed() }
                    root.wasOpen = !!root.popup
                    if (root.popup && root.spec) {
                        if (pl.source !== root.spec.src) { pl.active = false; pl.source = root.spec.src }
                        pl.active = true
                        if (pl.item) { pl.item.visible = true; if (root.popup.tab && pl.item.gotoTab) pl.item.gotoTab(root.popup.tab) }
                    } else if (pl.active) {
                        if (pl.item && pl.item.startExit) pl.item.startExit(() => { if (!root.popup || !root.spec) pl.active = false })
                        else pl.active = false
                    }
                }
            }

            Rectangle {
                id: card
                visible: root.spec === null
                readonly property int pad: 14
                width: Math.max(220, body.implicitWidth + 2 * pad)
                height: body.implicitHeight + 2 * pad
                x: Math.round(Math.max(8, Math.min(win.width - width - 8, (root.popup?.x ?? 0) - width / 2)))
                y: 54
                radius: BarStyle.radiusLarge
                antialiasing: true
                color: BarStyle.surface
                border.width: 1
                border.color: BarStyle.border
                opacity: 0
                property real slide: 8
                transform: Translate { y: card.slide }
                readonly property bool open: win.visible
                onOpenChanged: { opacity = open ? 1 : 0; slide = open ? 0 : 8 }
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on slide { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent }

                Loader {
                    id: body
                    x: card.pad; y: card.pad
                    property real implicitWidth: item?.implicitWidth ?? 0
                    property real implicitHeight: item?.implicitHeight ?? 0
                    sourceComponent: ({ notifications: notifications, clipboard: clipboard })[root.popup?.kind ?? ""] ?? null
                }
            }

            Component { id: notifications; NotificationsPopup {} }
            Component {
                id: clipboard
                Column {
                    id: clipCol
                    spacing: 4
                    property var rows: []
                    Process {
                        running: true
                        command: ["sh", "-c", "cliphist list | head -8"]
                        stdout: StdioCollector { onStreamFinished: clipCol.rows = text.split("\n").filter(l => l.length > 0) }
                    }
                    BarText { text: "Clipboard"; font.weight: Font.DemiBold }
                    BarText { visible: clipCol.rows.length === 0; text: "Empty"; color: BarStyle.subtext }
                    Repeater {
                        model: clipCol.rows
                        delegate: Item {
                            required property string modelData
                            width: 280; height: 28
                            Rectangle { anchors.fill: parent; radius: 10; color: ca.containsMouse ? BarStyle.plateHover : "transparent" }
                            BarText { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 264; elide: Text.ElideRight; text: modelData.replace(/^\d+\s+/, "") }
                            MouseArea {
                                id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", modelData]); root.close() }
                            }
                        }
                    }
                }
            }
        }
    }
}
