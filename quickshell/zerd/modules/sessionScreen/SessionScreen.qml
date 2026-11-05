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

        function press(): void { if (done) return; drain.stop(); fillLevel = Math.max(fillLevel, jar); fill.start() }
        function release(): void { if (done) return; fill.stop(); drain.start() }

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
                BarText { x: 0; y: 156; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: sb.fillLevel > 0.001 ? "keep holding" : "hold"; font.pixelSize: 11; color: BarStyle.subtext; opacity: 0.7 }
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
        Rectangle {
            visible: sb.hint.length > 0
            x: parent.width - 34; y: 12; width: 22; height: 22; radius: 8
            color: Qt.rgba(0, 0, 0, 0.3)
            BarText { anchors.centerIn: parent; text: sb.hint; font.pixelSize: 11; color: "#ffffff"; opacity: 0.8 }
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
                            hint: modelData.hint
                            danger: modelData.danger === true
                            weight: modelData.weight ?? 1
                            selected: content.sel === index
                            onActivated: content.run(modelData)
                        }
                    }
                }

                // Now playing - modeled on the gtklock media card: bigger
                // art, stacked title/artist, wavy seekbar, real controls -
                // last in the content group so it moves/centers as one unit
                // with the clock and buttons.
                Item {
                    id: nowPlayingCard
                    visible: NowPlaying.player !== null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    implicitWidth: 300
                    implicitHeight: nowPlayingCol.implicitHeight + 28

                    // Sibling of the content, not a wrapping parent - a
                    // parent's opacity multiplies into every child, which
                    // is what made the album art look washed out/hazy
                    // rather than just the background being translucent.
                    StyledRectangularShadow {
                        target: nowPlayingCardBg
                    }

                    GlassBackground {
                        id: nowPlayingCardBg
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        fallbackColor: Appearance.colors.colLayer3
                        screenX: nowPlayingCardBg.mapToItem(null, 0, 0).x
                        screenY: nowPlayingCardBg.mapToItem(null, 0, 0).y
                    }

                    ColumnLayout {
                        id: nowPlayingCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 16
                        }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 56
                                height: 56
                                radius: 12
                                antialiasing: true
                                color: Appearance.colors.colLayer3
                                clip: true

                                Image {
                                    id: nowPlayingArt
                                    anchors.fill: parent
                                    source: NowPlaying.player?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: width
                                    sourceSize.height: height
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: nowPlayingArt.status !== Image.Ready
                                    text: "music_note"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: 22
                                    color: Appearance.colors.colPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: Appearance.font.family.expressive
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: Appearance.colors.colOnLayer3
                                    text: NowPlaying.activeTrack?.title ?? ""
                                }
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: Appearance.font.family.expressive
                                    font.pixelSize: 12
                                    color: Appearance.colors.colOnLayer3
                                    opacity: 0.65
                                    text: NowPlaying.activeTrack?.artist ?? ""
                                }
                            }
                        }

                        WavySeekbar {
                            Layout.fillWidth: true
                            progress: (NowPlaying.player && NowPlaying.player.length > 0)
                                ? Math.max(0, Math.min(1, NowPlaying.player.position / NowPlaying.player.length)) : 0
                            accentColor: Appearance.colors.colPrimary
                            dimColor: ColorUtils.applyAlpha(Appearance.colors.colOnLayer3, 0.25)
                            amplitude: 4
                            animate: NowPlaying.isPlaying
                            onSeekRequested: fraction => {
                                if (!NowPlaying.player || NowPlaying.player.length <= 0) return
                                NowPlaying.player.position = fraction * NowPlaying.player.length
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 24

                            Text {
                                text: "skip_previous"
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 20
                                color: Appearance.colors.colOnLayer3
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NowPlaying.previous() }
                            }
                            Text {
                                text: NowPlaying.isPlaying ? "pause" : "play_arrow"
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 24
                                color: Appearance.colors.colOnLayer3
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NowPlaying.togglePlaying() }
                            }
                            Text {
                                text: "skip_next"
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 20
                                color: Appearance.colors.colOnLayer3
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NowPlaying.next() }
                            }
                        }

                        // Small equalizer, driven by the same cava data the
                        // media widget uses. Mirrored from the center (bass
                        // in the middle, treble at the edges) instead of a
                        // raw left-to-right sweep - reads as more musical
                        // and symmetric than one side just being louder.
                        RowLayout {
                            id: eqRow
                            readonly property int barCount: 20
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            spacing: 4

                            Repeater {
                                model: eqRow.barCount
                                delegate: Rectangle {
                                    id: eqBar
                                    required property int index
                                    readonly property int mirroredIndex: eqBar.index <= eqRow.barCount / 2
                                        ? eqBar.index
                                        : eqRow.barCount - eqBar.index
                                    readonly property real level: panelWindow.visualizerPoints.length > 0
                                        ? Math.max(0, Math.min(1, (panelWindow.visualizerPoints[Math.min(eqBar.mirroredIndex, panelWindow.visualizerPoints.length - 1)] ?? 0) / 1000))
                                        : 0
                                    Layout.alignment: Qt.AlignBottom
                                    implicitWidth: 3
                                    implicitHeight: 4 + level * 22
                                    radius: width / 2
                                    antialiasing: true
                                    color: Appearance.colors.colPrimary
                                    opacity: 0.45 + level * 0.55

                                    Behavior on implicitHeight { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }
                            }
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
