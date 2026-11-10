pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.desktopWidgets
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
        volume: { src: Qt.resolvedUrl("ilya/volume/VolumePopup.qml"), w: 410, h: 600, at: "right", m: 5 },
        calendar: { src: Qt.resolvedUrl("ilya/calendar/CalendarPopup.qml"), w: 1320, h: 470, at: "center", m: 0 },
        weather: { src: Qt.resolvedUrl("ilya/calendar/CalendarPopup.qml"), w: 1320, h: 470, at: "center", m: 0 },
        network: { src: Qt.resolvedUrl("ilya/network/NetworkPopup.qml"), w: 720, h: 600, at: "right", m: 4 },
        media: { src: Qt.resolvedUrl("ilya/media/MusicPopup.qml"), w: 625, h: 565, at: "left", m: 5 },
        battery: { src: Qt.resolvedUrl("ilya/battery/BatteryPopup.qml"), w: 440, h: 0, at: "right", m: 5, fit: true },
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
                    onLoaded: { item.visible = true; if (root.popup?.tab && item.gotoTab) item.gotoTab(root.popup.tab) }
                }
            }
            // A popup whose leave animation was interrupted never reports back; the window must not stay up over the screen
            Timer { id: exitGuard; interval: 700; onTriggered: if (!root.popup) pl.active = false }
            Connections {
                target: root
                function onPopupChanged() {
                    if (root.popup && !root.wasOpen) { Ilya.Sounds.popupOpened() }
                    else if (!root.popup && root.wasOpen) { Ilya.Sounds.popupClosed() }
                    root.wasOpen = !!root.popup
                    if (root.popup && root.spec) {
                        if (pl.source !== root.spec.src) { pl.active = false; pl.source = root.spec.src }
                        pl.active = true
                        if (pl.item) { pl.item.visible = true; if (root.popup.tab && pl.item.gotoTab) pl.item.gotoTab(root.popup.tab) }
                    } else if (pl.active) {
                        if (pl.item && pl.item.startExit) { pl.item.startExit(() => { if (!root.popup || !root.spec) pl.active = false }); exitGuard.restart() }
                        else pl.active = false
                    }
                }
            }

            Rectangle {
                id: card
                visible: root.spec === null && body.sourceComponent !== null
                readonly property int pad: 14
                width: Math.max(220, body.implicitWidth + 2 * pad)
                height: body.implicitHeight + 2 * pad
                readonly property bool atPointer: root.popup?.y !== undefined
                x: atPointer ? Math.round(Math.max(8, Math.min(win.width - width - 8, root.popup?.x ?? 0)))
                             : Math.round(Math.max(8, Math.min(win.width - width - 8, (root.popup?.x ?? 0) - width / 2)))
                y: atPointer ? Math.round(Math.max(8, Math.min(win.height - height - 8, root.popup?.y ?? 0))) : 54
                transformOrigin: Item.TopLeft
                scale: open ? 1 : 0.9
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
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
                    sourceComponent: ({ notifications: notifications, clipboard: clipboard, barmenu: barmenu, desktopmenu: desktopmenu })[root.popup?.kind ?? ""] ?? null
                }
            }

            // The right-click menu of the bar: the things you reach for most, one click each.
            Component {
                id: barmenu
                Column {
                    id: menuCol
                    spacing: 2
                    readonly property var items: [
                        { i: "tune", t: "Edit the bar", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "baredit", "open"]) },
                        { i: "settings", t: "Settings", f: () => { GlobalStates.settingsOpen = true } },
                        { i: "wallpaper", t: "Wallpapers", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "wallpaper", "toggle"]) },
                        { i: "widgets", t: "Desktop widgets", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "widgets", "toggleAll"]) },
                        { i: Notifications.silent ? "notifications" : "notifications_off", t: Notifications.silent ? "Turn notifications on" : "Do not disturb", f: () => Notifications.toggleSilent() },
                        { sep: true },
                        { i: "lock", t: "Lock", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"]) },
                        { i: "power_settings_new", t: "Power menu", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "sessionScreen", "toggle"]) }
                    ]
                    Repeater {
                        model: menuCol.items
                        delegate: Item {
                            id: mi
                            required property var modelData
                            width: 236; height: modelData.sep ? 9 : 40
                            Rectangle { visible: mi.modelData.sep === true; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: BarStyle.border; opacity: 0.6 }
                            Rectangle {
                                visible: !mi.modelData.sep
                                anchors.fill: parent; radius: BarStyle.radiusSmall
                                color: ma.pressed ? BarStyle.pressFill : ma.containsMouse ? BarStyle.hoverFill : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            BarIcon { visible: !mi.modelData.sep; x: 12; anchors.verticalCenter: parent.verticalCenter; name: mi.modelData.i ?? ""; size: 20; color: BarStyle.accent }
                            BarText { visible: !mi.modelData.sep; x: 44; anchors.verticalCenter: parent.verticalCenter; text: mi.modelData.t ?? "" }
                            MouseArea {
                                id: ma; enabled: !mi.modelData.sep; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.close(); mi.modelData.f() }
                            }
                        }
                    }
                }
            }

            // The desktop menu, after ilyamiro's: right-click the bare desktop, or a desktop widget.
            Component {
                id: desktopmenu
                Column {
                    id: dm
                    spacing: 6
                    readonly property string widget: root.popup?.widget ?? ""
                    function run(f) { root.close(); f() }
                    readonly property var icons: [
                        { i: "shuffle", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "wallpaper", "random"]) },
                        { i: "bedtime", on: Hyprsunset.active, f: () => Hyprsunset.toggle() },
                        { i: "refresh", f: () => Quickshell.reload(false) },
                        { i: "lock", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"]) }
                    ]
                    readonly property var rows: widget !== "" ? [
                        { i: "tune", t: "Edit widgets", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "widgetboard", "open"]) },
                        { i: "delete", t: "Remove this widget", danger: true, f: () => DesktopWidgets.set(dm.widget, false) }
                    ] : [
                        { i: "wallpaper", t: "Select wallpaper", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "wallpaper", "toggle"]) },
                        { i: "widgets", t: "Widget editor", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "widgetboard", "open"]) },
                        { i: "palette", t: "Colours", f: () => Quickshell.execDetached(["qs", "-c", "zerd", "ipc", "call", "settings", "page", "Colours"]) },
                        { i: "settings", t: "Settings", f: () => { GlobalStates.settingsOpen = true } }
                    ]
                    Row {
                        visible: dm.widget === ""
                        spacing: 6
                        Repeater {
                            model: dm.icons
                            delegate: Rectangle {
                                id: ib
                                required property var modelData
                                width: 52; height: 44; radius: BarStyle.radiusSmall
                                color: ima.pressed ? BarStyle.pressFill : (modelData.on ? BarStyle.accentContainer : (ima.containsMouse ? BarStyle.hoverFill : BarStyle.card))
                                Behavior on color { ColorAnimation { duration: 120 } }
                                BarIcon { anchors.centerIn: parent; name: ib.modelData.i; size: 22; color: ib.modelData.on ? BarStyle.accent : BarStyle.text }
                                MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dm.run(ib.modelData.f) }
                            }
                        }
                    }
                    Repeater {
                        model: dm.rows
                        delegate: Item {
                            id: rw
                            required property var modelData
                            width: 236; height: 40
                            Rectangle {
                                anchors.fill: parent; radius: BarStyle.radiusSmall
                                color: rma.pressed ? BarStyle.pressFill : rma.containsMouse ? (rw.modelData.danger ? Qt.alpha(BarStyle.danger, 0.18) : BarStyle.hoverFill) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            BarIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: rw.modelData.i; size: 20; color: rw.modelData.danger ? BarStyle.danger : BarStyle.accent }
                            BarText { x: 44; anchors.verticalCenter: parent.verticalCenter; text: rw.modelData.t; color: rw.modelData.danger ? BarStyle.danger : BarStyle.text }
                            MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dm.run(rw.modelData.f) }
                        }
                    }
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
