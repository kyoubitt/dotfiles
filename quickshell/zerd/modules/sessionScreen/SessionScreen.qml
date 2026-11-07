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
        property real weight: 1
        property bool selected: false
        property real leave: 0                  // 0..1, how far the menu has gone when another capsule fired
        property bool chosen: false             // this is the capsule that fired
        readonly property real level: hold.level
        readonly property bool lit: hold.resting || hold.level > 0.001
        property alias face: capsule             // the capsule itself: where the liquid floods out from
        signal activated()
        signal tapped()
        function press(): void { hold.keyDown() }
        function release(): void { hold.keyUp() }
        implicitWidth: 144
        implicitHeight: 196

        Rectangle {
            id: capsule
            anchors.fill: parent
            radius: BarStyle.radiusXL + 10
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, sb.lit ? 0.4 : 0.16)
            Behavior on border.color { ColorAnimation { duration: BarStyle.motionFast } }
            clip: true
            property real bob: 0
            transform: Translate { y: capsule.bob }
            scale: (hold.holding ? 0.97 : (sb.lit ? 1.03 : 1)) + (sb.chosen ? 0.07 * sb.leave : 0)
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

        // a quick tap only nudges the capsule: it does nothing until it is held
        SequentialAnimation {
            id: nudge
            NumberAnimation { target: capsule; property: "bob"; to: -9; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: capsule; property: "bob"; to: 0; duration: 380; easing.type: Easing.OutBounce }
        }

        HoldLogic {
            id: hold
            anchors.fill: parent
            weight: sb.weight
            selected: sb.selected
            onActivated: { flash.restart(); sb.activated() }
            onTapped: { nudge.restart(); sb.tapped() }
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

            // The whole menu fades in on open. Once a capsule has fired, everything except Lock is flooded by its liquid
            // (ExitFx) and what is under the flood stops drawing; Lock keeps the blurred backdrop for the lock screen.
            Item {
                id: stage
                anchors.fill: parent
                opacity: Math.min(content.enter * 3, 1)

                // Real frosted-glass backdrop: the actual wallpaper, blurred live.
                LockBackdrop {
                    anchors.fill: parent
                    visible: !fx.covered
                }

                ColumnLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 32
                    opacity: fx.covered ? 0 : 1           // not visible:false, it keeps the keyboard focus (Escape still works)

                    focus: true
                    property int sel: -1
                    property real enter: 0                // 0..1 while opening
                    property real leave: 0                // 0..1 once a capsule has fired
                    property bool fadeBackdrop: true      // false for Lock: the lock screen shows the same blurred wallpaper
                    property int chosen: -1
                    // fx is how the screen goes once the capsule has fired (ExitFx): fade to black, dim under a moon, or CRT off
                    readonly property var actions: [
                        { icon: "logout", label: "Log out", hint: "E", weight: 0.9, tone: "#f0b35a", fx: "fade", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
                        { icon: "lock", label: "Lock", hint: "L", weight: 0.6, tone: "accent", lock: true, cmd: ["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"] },
                        { icon: "bedtime", label: "Sleep", hint: "S", weight: 0.8, tone: "#9a97f5", fx: "sleep", cmd: ["sh", "-c", "sleep 1; systemctl suspend"] },
                        { icon: "restart_alt", label: "Restart", hint: "R", weight: 1.3, tone: "#f58f5f", fx: "crt", cmd: ["systemctl", "reboot"] },
                        { icon: "power_settings_new", label: "Shut down", hint: "U", weight: 1.6, tone: "#f2766d", fx: "crt", cmd: ["systemctl", "poweroff"] }
                    ]
                    property string hintText: "Hold a button to confirm"
                    property bool sent: false

                    // The capsule fired: the others fade away and, except for Lock, its liquid floods the window; the command
                    // goes out when that is over (send), with the window still up, and the window goes later (finish). Lock keeps
                    // the blurred backdrop up until the lock screen is really on screen, so the desktop never flashes between them.
                    function run(i: int): void {
                        if (chosen >= 0) return
                        chosen = i
                        const a = actions[i]
                        fadeBackdrop = !a.lock
                        leaveAnim.duration = a.lock ? 340 : 240
                        leaveAnim.start()
                        if (a.lock) {
                            Quickshell.execDetached(a.cmd.slice())
                            lockWait.start()
                            return
                        }
                        // the capsule as it is on screen right now (pressed in, scaled): the liquid starts as its exact shape
                        const f = capAt(i).face
                        const p = f.mapToItem(fx, 0, 0)
                        const q = f.mapToItem(fx, f.width, f.height)
                        fx.begin(a.fx, a.tone, a.icon, a.label, p.x, p.y, q.x - p.x, q.y - p.y, f.radius * (q.x - p.x) / f.width)
                        exitGuard.restart()
                    }
                    function send(): void {
                        if (sent) return
                        sent = true
                        Quickshell.execDetached(actions[chosen].cmd.slice())
                    }
                    function finish(): void {
                        if (!actions[chosen].lock) send()
                        GlobalStates.sessionOpen = false
                    }
                    NumberAnimation on enter { id: enterAnim; from: 0; to: 1; duration: 720; easing.type: Easing.OutCubic; running: true }
                    NumberAnimation { id: leaveAnim; target: content; property: "leave"; from: 0; to: 1; duration: 340; easing.type: Easing.InOutCubic }
                    // If the effect never gets to send the command (no frames are being drawn), send it and close anyway
                    Timer { id: exitGuard; interval: 1600; onTriggered: if (!content.sent) content.finish() }
                    // Lock: close once the lock screen covers us, or after a moment if it never does
                    Timer { id: lockWait; interval: 1500; onTriggered: content.finish() }
                    Connections {
                        target: GlobalStates
                        enabled: content.chosen >= 0 && content.actions[content.chosen].lock === true
                        function onScreenLockedChanged() { if (GlobalStates.screenLocked) { lockWait.stop(); content.finish() } }
                    }

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

                    Component.onCompleted: content.forceActiveFocus()

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        opacity: content.fadeBackdrop ? 1 - content.leave : 1
                        transform: Translate { y: (1 - Math.min(1, content.enter * 1.6)) * -18 }

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
                                id: cap
                                required property var modelData
                                required property int index
                                // each capsule rises a beat after the one before it
                                readonly property real appear: {
                                    const t = Math.max(0, Math.min(1, (content.enter - index * 0.07) / 0.55))
                                    return 1 - Math.pow(1 - t, 3)
                                }
                                icon: modelData.icon
                                label: modelData.label
                                tone: modelData.tone === "accent" ? BarStyle.accent : modelData.tone
                                weight: modelData.weight ?? 1
                                selected: content.sel === index
                                chosen: content.chosen === index
                                leave: content.leave
                                opacity: appear * (chosen ? 1 - (content.fadeBackdrop ? 0 : content.leave) : 1 - content.leave)
                                transform: Translate { y: (1 - cap.appear) * 40 + (cap.chosen ? 0 : cap.leave * 10) }
                                onActivated: content.run(index)
                                onTapped: { content.hintText = "Keep holding to " + modelData.label.toLowerCase(); hintReset.restart() }
                            }
                        }
                    }

                    BarText {
                        Layout.alignment: Qt.AlignHCenter
                        text: content.hintText
                        font.pixelSize: 14
                        color: content.hintText.indexOf("Keep") === 0 ? BarStyle.accent : "#ffffff"
                        opacity: (content.hintText.indexOf("Keep") === 0 ? 1 : 0.5) * Math.min(1, content.enter * 1.4) * (1 - content.leave)
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    Timer { id: hintReset; interval: 1800; onTriggered: content.hintText = "Hold a button to confirm" }
                }

                // On top of everything: the liquid of the fired capsule flooding the window, and what follows it
                ExitFx {
                    id: fx
                    anchors.fill: parent
                    onFire: content.send()
                    onFinished: content.finish()
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
