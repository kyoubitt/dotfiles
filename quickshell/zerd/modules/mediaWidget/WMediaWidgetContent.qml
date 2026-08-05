pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Rectangle {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.6)
    readonly property color dimWaveCol: ColorUtils.applyAlpha(SMColors.fg, 0.2)

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 32
    radius: 18
    antialiasing: true
    color: ColorUtils.applyAlpha(SMColors.bg, 0.55)
    border.width: 1
    border.color: ColorUtils.applyAlpha(SMColors.fg, 0.1)

    visible: player !== null

    // MPRIS position doesn't update reactively on its own while playing.
    Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    property list<real> visualizerPoints: []
    Process {
        id: cavaProc
        running: MprisController.isPlaying
        onRunningChanged: { if (!running) root.visualizerPoints = [] }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/media_widget_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }

    ColumnLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 16
        }
        spacing: 18

        // Circular art badge with thin bars radiating from its sides - no
        // ring border, no glow, no depth shadow around it, just art + bars.
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 250
            implicitHeight: 250

            Repeater {
                model: 24
                delegate: Item {
                    id: pivot
                    required property int index
                    anchors.centerIn: parent
                    width: 0
                    height: 0
                    rotation: pivot.index * (360 / 24)

                    Rectangle {
                        readonly property int mirroredIndex: pivot.index <= 12 ? pivot.index : 24 - pivot.index
                        readonly property int dataIndex: Math.min(mirroredIndex, root.visualizerPoints.length - 1)
                        readonly property real level: root.visualizerPoints.length > 0
                            ? Math.max(0, Math.min(1, root.visualizerPoints[dataIndex] / 1000))
                            : 0
                        width: 4
                        height: 6 + level * 26
                        radius: width / 2
                        antialiasing: true
                        color: ColorUtils.applyAlpha(SMColors.accent, 0.4 + level * 0.6)
                        x: -width / 2
                        y: -(artMask.width / 2 + 4) - height

                        Behavior on height {
                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }
                    }
                }
            }

            Item {
                id: artMask
                anchors.centerIn: parent
                width: 180
                height: 180

                RotationAnimation on rotation {
                    running: MprisController.isPlaying
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 12000
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: width
                    sourceSize.height: height
                    visible: false
                }
                Rectangle {
                    id: artMaskShape
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: artImage
                    maskSource: artMaskShape
                    visible: artImage.status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: artImage.status !== Image.Ready
                    text: "music_note"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 40
                    color: SMColors.accent
                }
            }
        }

        // Title / artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            MarqueeText {
                Layout.fillWidth: true
                font.pixelSize: 15
                font.bold: true
                color: SMColors.fg
                text: root.player?.trackTitle ?? ""
            }
            MarqueeText {
                Layout.fillWidth: true
                font.pixelSize: 12
                color: root.dimTextCol
                text: root.player?.trackArtist ?? ""
            }
        }

        // Wavy seek bar
        WavySeekbar {
            Layout.fillWidth: true
            progress: (root.player && root.player.length > 0)
                ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
            accentColor: SMColors.accent
            dimColor: root.dimWaveCol
            amplitude: 6
            animate: MprisController.isPlaying
            onSeekRequested: fraction => {
                if (!root.player || root.player.length <= 0) return
                root.player.position = fraction * root.player.length
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                color: root.dimTextCol
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                color: root.dimTextCol
                font.pixelSize: 10
            }
        }

        // Controls
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Text {
                text: "shuffle"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: MprisController.hasShuffle ? SMColors.accent : root.dimTextCol
                visible: MprisController.shuffleSupported
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MprisController.setShuffle(!MprisController.hasShuffle)
                }
            }
            Text {
                text: "skip_previous"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: SMColors.fg
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
            }
            Rectangle {
                implicitWidth: 34
                implicitHeight: 34
                radius: height / 2
                antialiasing: true
                color: SMColors.accent
                Text {
                    anchors.centerIn: parent
                    text: MprisController.isPlaying ? "pause" : "play_arrow"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: SMColors.bg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
            }
            Text {
                text: "skip_next"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: SMColors.fg
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.next() }
            }
            Text {
                text: "repeat"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: MprisController.loopState !== MprisLoopState.None ? SMColors.accent : root.dimTextCol
                visible: MprisController.loopSupported
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MprisController.setLoopState(
                        MprisController.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None)
                }
            }
        }
    }
}
