pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.bars

Scope {
    id: root

    // Hold-to-confirm capsule after ilyamiro's power actions (serpantinum, AGPL-3.0) and the liquid fill shader of the
    // Material You theme by Darkkal44 (MIT): press and hold, a wave fills the capsule, and when it is full the action runs.
    // Letting go drains it again. The heavier the action, the longer the hold.
    component SessionButton: Item {
        id: sb
        required property string icon
        required property string label
        property color tone: BarStyle.accent
        property bool danger: false
        property real weight: 1
        property bool selected: false
        property real level: 0                 // how full the jar is, 0..1
        property bool fired: false
        property bool holding: false
        property real pressedAt: 0
        readonly property bool resting: ma.containsMouse || sb.selected
        signal activated()
        implicitWidth: 144
        implicitHeight: 196
        readonly property bool lit: resting || level > 0.001

        // one animation drives the liquid: to half when you rest on it, to the top when you hold or click
        function go(to: real, ms: int, ease: int): void {
            lv.stop(); lv.from = sb.level; lv.to = to; lv.duration = Math.max(1, ms); lv.easing.type = ease; lv.start()
        }
        function rest(): void { if (!fired) go(resting ? 0.5 : 0, 600, Easing.OutCubic) }
        onRestingChanged: if (!holding) rest()
        function press(): void { if (fired) return; holding = true; pressedAt = Date.now(); go(1, 1000 * weight * (1 - level) + 120, Easing.InSine) }
        function release(): void {
            if (fired || !holding) return
            holding = false
            if (Date.now() - pressedAt < 260) go(1, 170, Easing.OutCubic)   // a plain click fills it at once
            else rest()
        }
        NumberAnimation { id: lv; target: sb; property: "level"
            onFinished: { if (sb.level >= 0.999 && !sb.fired) { sb.fired = true; flash.restart(); sb.activated() } } }

        Rectangle {
            id: capsule
            anchors.fill: parent
            radius: BarStyle.radiusXL + 10
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, sb.lit ? 0.4 : 0.16)
            Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
            clip: true
            scale: ma.pressed ? 0.97 : (sb.lit ? 1.03 : 1)
            Behavior on scale { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutBack } }

            ShaderEffect {
                anchors.fill: parent
                visible: sb.level > 0.001
                property real radius: capsule.radius
                property real fillLevel: sb.level
                property real waveAmp: sb.level < 0.99 ? Math.min(14, capsule.height * sb.level, capsule.height * (1 - sb.level)) * Math.sin(sb.level * Math.PI) : 0
                property vector2d itemSize: Qt.vector2d(width, height)
                property real phase: 0
                property real vertical: 1
                property color color1: Qt.darker(sb.tone, 1.1)
                property color color2: sb.tone
                property vector4d params: Qt.vector4d(1, 0, 0, 0)
                fragmentShader: Qt.resolvedUrl("fluid_wave.frag.qsb")
                NumberAnimation on phase { running: sb.level > 0 && sb.level < 1; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 800 }
            }
            Rectangle { anchors.fill: parent; radius: capsule.radius; color: "#ffffff"; opacity: 0
                NumberAnimation on opacity { id: flash; running: false; from: 0.6; to: 0; duration: 500; easing.type: Easing.OutExpo } }

            Item {
                anchors.fill: parent
                BarIcon { x: Math.round((parent.width - width) / 2); y: 52; name: sb.icon; size: 50; color: "#ffffff"; opacity: sb.lit ? 1 : 0.8 }
                BarText { x: 0; y: 128; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: sb.label; font.pixelSize: 15; color: "#ffffff"; opacity: sb.lit ? 1 : 0.8 }
            }
            // the same icon and name in the dark colour, only where the liquid is
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * sb.level
                clip: true
                Item {
                    x: 0; y: -(capsule.height - parent.height); width: capsule.width; height: capsule.height
                    BarIcon { x: Math.round((parent.width - width) / 2); y: 52; name: sb.icon; size: 50; color: BarStyle.onAccent }
                    BarText { x: 0; y: 128; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: sb.label; font.pixelSize: 15; color: BarStyle.onAccent }
                }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            acceptedButtons: Qt.LeftButton
            onPressed: sb.press()
            onReleased: sb.release()
            // a cancel while the pointer is still on the capsule is not you letting go: keep the hold going
            onCanceled: { console.log("[power] press cancelled on " + sb.label); if (!ma.containsMouse) sb.release() }
        }
    }

    LazyLoader {
        active: GlobalStates.sessionOpen

        PanelWindow {
            id: panelWindow
            WlrLayershell.namespace: "quickshell:sessionScreen"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }

            // Real frosted-glass backdrop: the actual wallpaper, blurred live,
            // rather than a flat dimmed rectangle - static power-menu tools
            // can't do this without a pre-baked screenshot.
            LockBackdrop {
                anchors.fill: parent
            }

            // Entrance: fade + rise, so it feels like something actually
            // happened rather than just popping into existence.
            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 32
                opacity: 0
                property real riseOffset: 24
                anchors.verticalCenterOffset: riseOffset

                focus: true
                property int sel: -1
                readonly property var actions: [
                    { icon: "logout", label: "Log out", hint: "E", weight: 1.3, tone: "#f0b35a", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
                    { icon: "lock", label: "Lock", hint: "L", weight: 0.8, tone: "accent", cmd: ["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"] },
                    { icon: "bedtime", label: "Sleep", hint: "S", weight: 1, tone: "#9a97f5", cmd: ["sh", "-c", "sleep 1; systemctl suspend"] },
                    { icon: "restart_alt", label: "Restart", hint: "R", weight: 2, tone: "#f58f5f", cmd: ["systemctl", "reboot"] },
                    { icon: "power_settings_new", label: "Shut down", hint: "U", weight: 2.8, tone: "#f2766d", cmd: ["systemctl", "poweroff"] }
                ]
                // the command goes out first: closing the window destroys this item, and a command sent after that was lost
                function run(a): void { Quickshell.execDetached(a.cmd.slice()); GlobalStates.sessionOpen = false }
                function capAt(i: int): var { return caps.itemAt(i) }
                Keys.onEscapePressed: GlobalStates.sessionOpen = false
                Keys.onLeftPressed: sel = sel <= 0 ? actions.length - 1 : sel - 1
                Keys.onRightPressed: sel = (sel + 1) % actions.length
                // keys do what the mouse does: hold to fill, let go to drain
                Keys.onReturnPressed: event => { if (!event.isAutoRepeat && sel >= 0) capAt(sel)?.press() }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat && sel >= 0) capAt(sel)?.press() }
                Keys.onReleased: event => {
                    if (event.isAutoRepeat) return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (sel >= 0) capAt(sel)?.release(); return }
                    const i = actions.findIndex(a => event.key === Qt["Key_" + a.hint])
                    if (i >= 0) capAt(i)?.release()
                }
                Keys.onPressed: event => {
                    if (event.isAutoRepeat) return
                    const i = actions.findIndex(a => event.key === Qt["Key_" + a.hint])
                    if (i >= 0) { sel = i; capAt(i)?.press(); event.accepted = true }
                }

                Component.onCompleted: {
                    entranceAnim.start()
                    content.forceActiveFocus()
                }

                ParallelAnimation {
                    id: entranceAnim
                    NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutQuad }
                    NumberAnimation { target: content; property: "riseOffset"; from: 24; to: 0; duration: 320; easing.type: Easing.OutQuad }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    BarText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "hh:mm")
                        font.pixelSize: 88
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                    BarText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, d MMMM")
                        font.pixelSize: 18
                        color: BarStyle.accent
                    }
                }

                RowLayout {
                    id: actionRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18
                    Repeater {
                        id: caps
                        model: content.actions
                        delegate: SessionButton {
                            required property var modelData
                            required property int index
                            icon: modelData.icon
                            label: modelData.label
                            tone: modelData.tone === "accent" ? BarStyle.accent : modelData.tone
                            weight: modelData.weight ?? 1
                            selected: content.sel === index
                            onActivated: content.run(modelData)
                        }
                    }
                }

            }
        }
    }

    IpcHandler {
        target: "sessionScreen"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        function open(): void { GlobalStates.sessionOpen = true }
        function close(): void { GlobalStates.sessionOpen = false }
    }
}
