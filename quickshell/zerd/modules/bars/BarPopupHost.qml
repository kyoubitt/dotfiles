pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common

// One popup at a time under the top bar (GlobalStates.barPopup): calendar,
// media, volume, brightness, network, battery and system details. Click
// outside or Escape closes it.
Scope {
    id: root

    readonly property var popup: GlobalStates.barPopup

    readonly property bool overview: NiriService.inOverview
    onOverviewChanged: if (overview) GlobalStates.barPopup = null

    // `ipc call barpopup open <kind>` opens a popup centred on the screen's top; `close` closes it.
    IpcHandler {
        target: "barpopup"
        function open(kind: string): void { BarState.sidebar = ""; GlobalStates.barPopup = { kind: kind, x: 960 } }
        function close(): void { GlobalStates.barPopup = null }
    }
    function close(): void { GlobalStates.barPopup = null }

    // Created once and shown/hidden, so a click never waits for the window to be built.
    Item {
        PanelWindow {
            id: win
            visible: root.popup !== null && !NiriService.inOverview && !GlobalStates.screenLocked
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

            Rectangle {
                id: card
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
                    sourceComponent: ({
                        calendar: calendar, clock: clock, weather: weather, tray: tray, media: media, volume: volume, brightness: brightness,
                        network: network, battery: battery, system: system, notifications: notifications, clipboard: clipboard, traymenu: traymenu
                    })[root.popup?.kind ?? ""] ?? null
                }
            }

            Component { id: calendar; CalendarCard {} }
            Component { id: clock; ClockPopup {} }
            Component { id: media; MediaPopup {} }
            Component { id: weather; WeatherPopup {} }
            Component { id: tray; TrayPopup { window: win } }
            Component { id: traymenu; TrayMenu { itemId: root.popup?.item ?? "" } }
            Component { id: volume; VolumePopup {} }
            Component { id: brightness; BrightnessPopup { screen: win.screen } }
            Component { id: network; NetworkPopup {} }
            Component { id: battery; BatteryPopup {} }
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
            Component { id: system; SystemPopup {} }
        }
    }
}
