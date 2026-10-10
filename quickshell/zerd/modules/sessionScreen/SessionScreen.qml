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

Scope {
    id: root

    component SessionButton: ColumnLayout {
        id: sessionButton
        required property string icon
        required property string label
        signal activated()

        spacing: 10

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 120
            implicitHeight: 120

            StyledRectangularShadow {
                target: sessionButtonRipple
                radius: Appearance.rounding.full
            }

            RippleButton {
                id: sessionButtonRipple
                anchors.fill: parent
                buttonRadius: Appearance.rounding.full
                pointingHandCursor: true

                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colPrimary
                colRipple: Appearance.colors.colPrimaryActive

                scale: sessionButtonRipple.buttonHovered ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                releaseAction: () => sessionButton.activated()

                contentItem: Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: sessionButton.icon
                    font.family: Appearance.font.family.iconMaterial
                    font.pixelSize: 42
                    color: sessionButtonRipple.buttonHovered ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: sessionButton.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: 15
            font.bold: true
            color: Appearance.colors.colOnLayer0
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
                                    text: MprisController.activeTrack?.title ?? ""
                                }
                                MarqueeText {
                                    Layout.fillWidth: true
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: 12
                                    color: Appearance.colors.colOnLayer3
                                    opacity: 0.65
                                    text: MprisController.activeTrack?.artist ?? ""
                                }
                            }
                        }

                        WavySeekbar {
                            Layout.fillWidth: true
                            progress: (MprisController.activePlayer && MprisController.activePlayer.length > 0)
                                ? Math.max(0, Math.min(1, MprisController.activePlayer.position / MprisController.activePlayer.length)) : 0
                            accentColor: Appearance.colors.colPrimary
                            dimColor: ColorUtils.applyAlpha(Appearance.colors.colOnLayer3, 0.25)
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
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 20
                                color: Appearance.colors.colOnLayer3
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
                            }
                            Text {
                                text: MprisController.isPlaying ? "pause" : "play_arrow"
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 24
                                color: Appearance.colors.colOnLayer3
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
                            }
                            Text {
                                text: "skip_next"
                                font.family: Appearance.font.family.iconMaterial
                                font.pixelSize: 20
                                color: Appearance.colors.colOnLayer3
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
