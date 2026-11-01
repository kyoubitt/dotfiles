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

    // A tonal tile with the icon, the name and the key that does it. Hover and the keyboard focus lift it and fill it
    // with the accent; the destructive ones (reboot, shut down) fill with the warning colour instead.
    component SessionButton: ColumnLayout {
        id: sessionButton
        required property string icon
        required property string label
        property string hint: ""
        property bool danger: false
        signal activated()
        readonly property color tone: sessionButton.danger ? BarStyle.danger : BarStyle.accent

        spacing: 12

        Rectangle {
            id: tile
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 96
            implicitHeight: 96
            radius: 48
            readonly property bool lit: tileHover.hovered || tileTap.pressed
            color: lit ? Qt.rgba(sessionButton.tone.r, sessionButton.tone.g, sessionButton.tone.b, 0.92) : Qt.rgba(0, 0, 0, 0.32)
            border.width: 1
            border.color: lit ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
            scale: tileTap.pressed ? 0.94 : (lit ? 1.05 : 1)
            Behavior on color { ColorAnimation { duration: 110 } }
            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: sessionButton.icon
                font.family: Appearance.font.family.iconMaterial
                font.pixelSize: 38
                color: tile.lit ? BarStyle.onAccent : "#ffffff"
                Behavior on color { ColorAnimation { duration: 110 } }
            }
            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: tileTap; onTapped: sessionButton.activated() }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: sessionButton.label
            font.pixelSize: 14
            font.weight: Font.Medium
            color: "#ffffff"
            opacity: tile.lit ? 1 : 0.7
            Behavior on opacity { NumberAnimation { duration: 110 } }
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
                Keys.onEscapePressed: GlobalStates.sessionOpen = false
                Keys.onPressed: event => {
                    const k = event.key
                    const go = (cmd) => { GlobalStates.sessionOpen = false; Quickshell.execDetached(cmd); event.accepted = true }
                    if (k === Qt.Key_L) go(["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"])
                    else if (k === Qt.Key_S) go(["systemctl", "suspend"])
                    else if (k === Qt.Key_R) go(["systemctl", "reboot"])
                    else if (k === Qt.Key_U) go(["systemctl", "poweroff"])
                    else if (k === Qt.Key_E) go(["niri", "msg", "action", "quit", "--skip-confirmation"])
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

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "hh:mm AP")
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 72
                        font.bold: true
                        color: Appearance.colors.colOnLayer0
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d")
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 18
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 28

                    SessionButton {
                        icon: "logout"
                        label: "Log out"
                        hint: "E"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"])
                        }
                    }
                    SessionButton {
                        icon: "lock"
                        label: "Lock"
                        hint: "L"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"])
                        }
                    }
                    SessionButton {
                        icon: "bedtime"
                        label: "Sleep"
                        hint: "S"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["systemctl", "suspend"])
                        }
                    }
                    SessionButton {
                        icon: "restart_alt"
                        label: "Reboot"
                        hint: "R"
                        danger: true
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["systemctl", "reboot"])
                        }
                    }
                    SessionButton {
                        icon: "power_settings_new"
                        label: "Shut down"
                        hint: "U"
                        danger: true
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["systemctl", "poweroff"])
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
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: Appearance.colors.colOnLayer3
                                    text: NowPlaying.activeTrack?.title ?? ""
                                }
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: Appearance.font.family.monospace
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
