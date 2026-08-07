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
import qs.modules.waffle.startMenu

Scope {
    id: root

    component SessionButton: ColumnLayout {
        id: sessionButton
        required property string icon
        required property string label
        readonly property bool hovered: buttonMouse.containsMouse
        signal activated()

        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 120
            height: 120
            radius: width / 2
            antialiasing: true
            color: SMColors.accent
            opacity: sessionButton.hovered ? 0.85 : 0.5
            scale: sessionButton.hovered ? 1.06 : 1.0

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            Text {
                anchors.centerIn: parent
                text: sessionButton.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 42
                color: SMColors.fg
            }

            MouseArea {
                id: buttonMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sessionButton.activated()
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: sessionButton.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.bold: true
            color: SMColors.fg
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
                running: MprisController.isPlaying
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
            Image {
                id: bgSource
                anchors.fill: parent
                source: Wallpapers.effectiveWallpaperUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
                cache: true

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    source: bgSource
                    anchors.fill: bgSource
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                }
            }
            Rectangle {
                anchors.fill: parent
                color: SMColors.bg
                opacity: 0.45
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
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 72
                        font.bold: true
                        color: SMColors.fg
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: SMColors.fg
                        opacity: 0.7
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 36

                    SessionButton {
                        icon: "lock"
                        label: "Lock"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["/usr/bin/qs", "-c", "zerd", "ipc", "call", "lockScreen", "lock"])
                        }
                    }
                    SessionButton {
                        icon: "bedtime"
                        label: "Sleep"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["systemctl", "suspend"])
                        }
                    }
                    SessionButton {
                        icon: "restart_alt"
                        label: "Reboot"
                        onActivated: {
                            GlobalStates.sessionOpen = false
                            Quickshell.execDetached(["systemctl", "reboot"])
                        }
                    }
                    SessionButton {
                        icon: "power_settings_new"
                        label: "Shutdown"
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
                    visible: MprisController.activePlayer !== null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    implicitWidth: 300
                    implicitHeight: nowPlayingCol.implicitHeight + 28

                    // Sibling of the content, not a wrapping parent - a
                    // parent's opacity multiplies into every child, which
                    // is what made the album art look washed out/hazy
                    // rather than just the background being translucent.
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        antialiasing: true
                        color: "gray"
                        opacity: 0.35
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
                                color: SMColors.bg
                                clip: true

                                Image {
                                    id: nowPlayingArt
                                    anchors.fill: parent
                                    source: MprisController.activePlayer?.trackArtUrl ?? ""
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
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 22
                                    color: SMColors.accent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: SMColors.fg
                                    text: MprisController.activeTrack?.title ?? ""
                                }
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: SMColors.fg
                                    opacity: 0.65
                                    text: MprisController.activeTrack?.artist ?? ""
                                }
                            }
                        }

                        WavySeekbar {
                            Layout.fillWidth: true
                            progress: (MprisController.activePlayer && MprisController.activePlayer.length > 0)
                                ? Math.max(0, Math.min(1, MprisController.activePlayer.position / MprisController.activePlayer.length)) : 0
                            accentColor: SMColors.accent
                            dimColor: ColorUtils.applyAlpha(SMColors.fg, 0.25)
                            amplitude: 4
                            animate: MprisController.isPlaying
                            onSeekRequested: fraction => {
                                if (!MprisController.activePlayer || MprisController.activePlayer.length <= 0) return
                                MprisController.activePlayer.position = fraction * MprisController.activePlayer.length
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 24

                            Text {
                                text: "skip_previous"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: SMColors.fg
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
                            }
                            Text {
                                text: MprisController.isPlaying ? "pause" : "play_arrow"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 24
                                color: SMColors.fg
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
                            }
                            Text {
                                text: "skip_next"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                color: SMColors.fg
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.next() }
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
                                    color: SMColors.accent
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
