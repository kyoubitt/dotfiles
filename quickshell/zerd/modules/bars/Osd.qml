pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common

// A small pill for the things that matter: volume, brightness, mic mute and Caps Lock. It appears on the screen you are working on, never takes the pointer, and updates in
// place while a key is held. `ipc call osd display <kind> [percent]` shows one for testing.
Scope {
    id: root

    readonly property var options: Config.options?.bars?.osd ?? ({})
    readonly property bool enabled: options.enable ?? true
    readonly property string position: options.position ?? "bottom"
    readonly property int timeout: options.timeout ?? 1500

    // What the pill shows right now.
    property string icon: ""
    property string label: ""
    property real value: -1          // 0..1 draws a bar; -1 = text only
    property string text: ""
    property bool shown: false
    property bool warm: false        // quiet for the first moments, while services report their state

    // Nothing is shown while the user is already looking at a slider or the screen is covered.
    readonly property bool quiet: BarState.sidebar !== "" || GlobalStates.barPopup !== null || NiriService.inOverview || GlobalStates.screenLocked

    Timer { interval: 3000; running: true; onTriggered: root.warm = true }
    Timer { id: hide; interval: root.timeout; onTriggered: root.shown = false }

    function show(icon: string, label: string, value: real, text: string): void {
        if (!root.enabled || !root.warm || root.quiet) return
        root.icon = icon; root.label = label; root.value = value; root.text = text
        root.shown = true
        hide.restart()
    }

    function showVolume(): void {
        const a = Audio.sink?.audio
        if (!a) return
        const v = a.volume ?? 0
        root.show(a.muted || v <= 0 ? "volume_off" : (v < 0.5 ? "volume_down" : "volume_up"), "Volume", a.muted ? 0 : Math.min(1, v), a.muted ? "Muted" : Math.round(v * 100) + "%")
    }
    function showBrightness(): void {
        const m = Brightness.monitors[0]
        if (!m) return
        root.show("brightness_6", "Brightness", m.brightness, Math.round(m.brightness * 100) + "%")
    }
    function showMic(): void {
        const muted = Audio.source?.audio?.muted ?? false
        root.show(muted ? "mic_off" : "mic", "Microphone", -1, muted ? "Microphone muted" : "Microphone on")
    }

    Connections { target: Audio.sink?.audio ?? null; function onVolumeChanged(): void { root.showVolume() } function onMutedChanged(): void { root.showVolume() } }
    Connections { target: Audio.source?.audio ?? null; function onMutedChanged(): void { root.showMic() } }
    Connections { target: Brightness; function onBrightnessChanged(): void { root.showBrightness() } }
    // Caps and num lock have no event; the keyboard LEDs are read a few times a second by one shell loop.
    property string locks: ""
    Process {
        running: root.enabled
        command: ["sh", "-c", "while :; do c=$(cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -1); n=$(cat /sys/class/leds/*::numlock/brightness 2>/dev/null | sort -rn | head -1); echo \"${c:-0}${n:-0}\"; sleep 0.3; done"]
        stdout: SplitParser {
            onRead: line => {
                const now = line.trim()
                const was = root.locks
                root.locks = now
                if (was === "" || was === now || now.length < 2) return
                if (was[0] !== now[0]) root.show("keyboard_capslock", "Caps Lock", -1, now[0] !== "0" ? "Caps Lock on" : "Caps Lock off")
            }
        }
    }

    IpcHandler {
        target: "osd"
        function display(kind: string, percent: string): void {
            const p = Math.max(0, Math.min(100, parseInt(percent))) / 100
            const wasWarm = root.warm
            root.warm = true
            if (kind === "volume") root.show("volume_up", "Volume", isNaN(p) ? 0.5 : p, (isNaN(p) ? 50 : Math.round(p * 100)) + "%")
            else if (kind === "brightness") root.show("brightness_6", "Brightness", isNaN(p) ? 0.5 : p, (isNaN(p) ? 50 : Math.round(p * 100)) + "%")
            else if (kind === "mic") root.show("mic_off", "Microphone", -1, "Microphone muted")
            else if (kind === "caps") root.show("keyboard_capslock", "Caps Lock", -1, "Caps Lock on")
            else if (kind === "layout") root.show("keyboard", "Layout", -1, "English (US)")
            else if (kind === "media") root.show("play_arrow", "Media", -1, "Playing")
            root.warm = wasWarm
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool mine: Quickshell.screens.length < 2 || win.modelData.name === NiriService.currentOutput

            screen: modelData
            visible: win.mine && (root.shown || pill.opacity > 0.01)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 420
            implicitHeight: 96
            anchors { top: root.position === "top"; bottom: root.position !== "top" }
            margins.top: 70
            margins.bottom: 110
            WlrLayershell.namespace: "quickshell:zerd-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            Rectangle {
                id: pill
                readonly property bool bar: root.value >= 0
                width: bar ? 300 : Math.max(180, line.implicitWidth + 56)
                height: 56
                radius: 28
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2) + (root.shown ? 0 : (root.position === "top" ? -8 : 8))
                color: BarStyle.surface
                border.width: 1
                border.color: BarStyle.border
                opacity: root.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 110 } }
                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                BarIcon { x: 20; anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: 24; fill: 1; color: BarStyle.accent }

                // Bar and percentage.
                Item {
                    visible: pill.bar
                    x: 58; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 58 - 78; height: 8
                    Rectangle { anchors.fill: parent; radius: 4; color: BarStyle.border }
                    Rectangle {
                        width: Math.max(8, parent.width * Math.max(0, Math.min(1, root.value))); height: parent.height; radius: 4
                        color: BarStyle.accent
                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                    }
                }
                BarText {
                    visible: pill.bar
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    text: root.text
                    font.weight: Font.DemiBold
                }

                // Text only.
                BarText {
                    id: line
                    visible: !pill.bar
                    x: 58; anchors.verticalCenter: parent.verticalCenter
                    text: root.text
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
