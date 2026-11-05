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
        property string hint: ""
        property bool danger: false
        property real weight: 1
        property bool selected: false
        property real fillLevel: 0
        // like liquid in a jar: resting the pointer on a capsule fills it part way, holding fills the rest
        property real jar: ma.containsMouse && !done ? 0.4 : 0
        Behavior on jar { NumberAnimation { duration: 1100; easing.type: Easing.OutCubic } }
        readonly property real level: Math.max(fillLevel, jar)
        property bool done: false
        signal activated()
        implicitWidth: 144
        implicitHeight: 196
        readonly property color tone: sb.danger ? BarStyle.danger : BarStyle.accent
        readonly property bool lit: ma.containsMouse || sb.selected || level > 0.001

        function press(): void { if (done) return; pressedAt = Date.now(); drain.stop(); fillLevel = Math.max(fillLevel, jar); fill.start() }
        property real pressedAt: 0
        function release(): void {
            if (done) return
            fill.stop()
            if (Date.now() - pressedAt < 320) { fillLevel = 1; done = true; flash.restart(); sb.activated(); return }   // a plain click
            drain.start()
        }

        NumberAnimation { id: fill; target: sb; property: "fillLevel"; to: 1; duration: 520 * sb.weight * (1 - sb.fillLevel); easing.type: Easing.InSine
            onFinished: { sb.done = true; flash.restart(); sb.activated() } }
        NumberAnimation { id: drain; target: sb; property: "fillLevel"; to: 0; duration: 1200 * sb.fillLevel; easing.type: Easing.OutQuad }

        Rectangle {
            id: capsule
            anchors.fill: parent
            radius: BarStyle.radiusXL + 10
            color: ma.containsMouse || sb.selected ? BarStyle.cardHigh : BarStyle.card
            border.width: sb.selected ? 2 : 0
            border.color: sb.tone
            clip: true
            scale: ma.pressed ? 0.97 : (sb.lit ? 1.03 : 1)
            Behavior on color { ColorAnimation { duration: BarStyle.motionFast } }
            Behavior on scale { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutBack } }

            ShaderEffect {
                id: wave
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

            // icon and name; a second copy, clipped to the filled part, turns dark on the wave
            Item {
                anchors.fill: parent
                BarIcon { x: Math.round((parent.width - width) / 2); y: 52; name: sb.icon; size: 50; color: sb.lit ? BarStyle.text : BarStyle.subtext }
                BarText { x: 0; y: 128; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: sb.label; font.pixelSize: 15; color: sb.lit ? BarStyle.text : BarStyle.subtext }
            }
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
            onPressed: sb.press()
            onReleased: sb.release()
            onCanceled: sb.release()
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

            property list<real> visualizerPoints: []
            Process {
                id: cavaProc
                running: NowPlaying.isPlaying
                onRunningChanged: { if (!running) panelWindow.visualizerPoints = [] }
                command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/media_widget_config.txt`]
                stdout: SplitParser {
                    onRead: data => {
                        panelWindow.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
                    }
                }
            }

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
                    { icon: "logout", label: "Log out", hint: "E", weight: 1.3, cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
                    { icon: "lock", label: "Lock", hint: "L", weight: 0.8, cmd: ["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"] },
                    { icon: "bedtime", label: "Sleep", hint: "S", weight: 1, cmd: ["sh", "-c", "sleep 1; systemctl suspend"] },
                    { icon: "restart_alt", label: "Restart", hint: "R", weight: 2, danger: true, cmd: ["systemctl", "reboot"] },
                    { icon: "power_settings_new", label: "Shut down", hint: "U", weight: 2.8, danger: true, cmd: ["systemctl", "poweroff"] }
                ]
                function run(a): void { GlobalStates.sessionOpen = false; Quickshell.execDetached(a.cmd) }
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
                            hint: ""
                            danger: modelData.danger === true
                            weight: modelData.weight ?? 1
                            selected: content.sel === index
                            onActivated: content.run(modelData)
                        }
                    }
                }

                // What is playing: a wide card, the cover, the words, a smooth bar and three liquid round buttons.
                Rectangle {
                    id: nowPlayingCard
                    visible: NowPlaying.player !== null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    implicitWidth: 640
                    implicitHeight: 148
                    radius: BarStyle.radiusXL + 6
                    color: BarStyle.card
                    antialiasing: true

                    Item {
                        id: coverBox
                        x: 20; y: 20; width: 108; height: 108
                        Rectangle { anchors.fill: parent; radius: 30; color: BarStyle.cardHigh
                            BarIcon { anchors.centerIn: parent; name: "music_note"; size: 38; color: BarStyle.accent } }
                        Image { id: coverImg; anchors.fill: parent; source: NowPlaying.player?.trackArtUrl ?? ""; sourceSize: Qt.size(216, 216); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
                        Rectangle { id: coverMask; anchors.fill: parent; radius: 30; visible: false; layer.enabled: true }
                        MultiEffect { anchors.fill: parent; source: coverImg; visible: coverImg.status === Image.Ready; maskEnabled: true; maskSource: coverMask }
                    }
                    Column {
                        x: 148; y: 24; width: parent.width - 148 - 24
                        spacing: 2
                        BarText { width: parent.width; elide: Text.ElideRight; text: NowPlaying.activeTrack?.title ?? ""; font.pixelSize: 20; font.weight: Font.DemiBold }
                        BarText { width: parent.width; elide: Text.ElideRight; text: NowPlaying.activeTrack?.artist ?? ""; font.pixelSize: 14; color: BarStyle.subtext }
                    }
                    // the bar: a thin pill that fills with the accent; a click or drag seeks
                    Item {
                        id: prog
                        x: 148; y: 78; width: parent.width - 148 - 24; height: 14
                        readonly property real frac: (NowPlaying.player && NowPlaying.player.length > 0) ? Math.max(0, Math.min(1, NowPlaying.player.position / NowPlaying.player.length)) : 0
                        Timer { interval: 1000; repeat: true; running: NowPlaying.isPlaying; onTriggered: NowPlaying.player?.positionChanged() }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: BarStyle.cardHigh }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * prog.frac; height: 6; radius: 3; color: BarStyle.accent
                            Behavior on width { NumberAnimation { duration: 900 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => { if (NowPlaying.player && NowPlaying.player.length > 0) NowPlaying.player.position = NowPlaying.player.length * (mouse.x / width) } }
                    }
                    Row {
                        x: 148; y: 98
                        spacing: 12
                        LiquidRound { icon: "skip_previous"; onActivated: NowPlaying.previous() }
                        LiquidRound { icon: NowPlaying.isPlaying ? "pause" : "play_arrow"; big: true; onActivated: NowPlaying.togglePlaying() }
                        LiquidRound { icon: "skip_next"; onActivated: NowPlaying.next() }
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
