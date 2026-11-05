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

    // A big rounded tile with the icon, the name and the key that does it. Hover or the keyboard selection fills it
    // with the accent; the destructive ones (reboot, shut down) fill with the warning colour instead.
    component SessionButton: Item {
        id: sb
        required property string icon
        required property string label
        property string hint: ""
        property bool danger: false
        property bool selected: false
        signal activated()
        implicitWidth: 120
        implicitHeight: 150
        readonly property color tone: sb.danger ? BarStyle.danger : BarStyle.accent
        readonly property bool lit: btn.hovered || sb.selected

        BarButton {
            id: btn
            width: 112; height: 112
            anchors.horizontalCenter: parent.horizontalCenter
            radius: lit ? 40 : 32
            Behavior on radius { NumberAnimation { duration: BarStyle.motionNormal; easing.type: Easing.OutCubic } }
            tone: sb.lit ? "filled" : "tonal"
            accentColor: sb.tone
            onAccentColor: sb.danger ? BarStyle.onAccent : BarStyle.onAccent
            onTapped: sb.activated()
            BarIcon { anchors.centerIn: parent; name: sb.icon; size: 44; color: btn.ink }
        }
        BarText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 124
            text: sb.label
            font.pixelSize: 14
            color: sb.lit ? BarStyle.text : BarStyle.subtext
        }
        Rectangle {
            visible: sb.hint.length > 0
            x: btn.x + btn.width - 28; y: 6
            width: 22; height: 22; radius: 8
            color: Qt.rgba(0, 0, 0, 0.35)
            BarText { anchors.centerIn: parent; text: sb.hint; font.pixelSize: 11; color: "#ffffff"; opacity: 0.8 }
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
                    { icon: "logout", label: "Log out", hint: "E", cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
                    { icon: "lock", label: "Lock", hint: "L", cmd: ["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"] },
                    { icon: "bedtime", label: "Sleep", hint: "S", cmd: ["sh", "-c", "sleep 1; systemctl suspend"] },
                    { icon: "restart_alt", label: "Restart", hint: "R", danger: true, cmd: ["systemctl", "reboot"] },
                    { icon: "power_settings_new", label: "Shut down", hint: "U", danger: true, cmd: ["systemctl", "poweroff"] }
                ]
                function run(a): void { GlobalStates.sessionOpen = false; Quickshell.execDetached(a.cmd) }
                Keys.onEscapePressed: GlobalStates.sessionOpen = false
                Keys.onLeftPressed: sel = sel <= 0 ? actions.length - 1 : sel - 1
                Keys.onRightPressed: sel = (sel + 1) % actions.length
                Keys.onReturnPressed: if (sel >= 0) run(actions[sel])
                Keys.onEnterPressed: if (sel >= 0) run(actions[sel])
                Keys.onPressed: event => {
                    const hit = actions.find(a => event.key === Qt["Key_" + a.hint])
                    if (hit) { run(hit); event.accepted = true }
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
                        model: content.actions
                        delegate: SessionButton {
                            required property var modelData
                            required property int index
                            icon: modelData.icon
                            label: modelData.label
                            hint: modelData.hint
                            danger: modelData.danger === true
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
