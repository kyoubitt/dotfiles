pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Rectangle {
    id: root

    readonly property color textCol: SMColors.fg
    readonly property color dimTextCol: ColorUtils.applyAlpha(SMColors.fg, 0.6)
    readonly property color trackBg: ColorUtils.mix(SMColors.fg, SMColors.bg, 0.14)

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 28
    radius: 18
    antialiasing: true
    color: ColorUtils.applyAlpha(SMColors.bg, 0.7)
    border.width: 1
    border.color: ColorUtils.applyAlpha(SMColors.fg, 0.1)

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

    // MPRIS position doesn't update reactively on its own while playing.
    Timer {
        running: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: MprisController.activePlayer?.positionChanged()
    }

    component IconText: Text {
        font.family: "Material Symbols Rounded"
        color: root.textCol
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IconText { text: "music_note"; font.pixelSize: 16 }
            Text {
                Layout.fillWidth: true
                text: Translation.tr("Now Playing")
                color: root.textCol
                font.pixelSize: 14
                font.bold: true
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 40
            Layout.bottomMargin: 40
            Layout.alignment: Qt.AlignHCenter
            visible: MprisController.activePlayer === null
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Nothing playing")
            color: root.dimTextCol
            font.pixelSize: 12
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: MprisController.activePlayer !== null
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: 64
                    implicitHeight: 64
                    radius: 12
                    antialiasing: true
                    color: root.trackBg
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: MprisController.activeTrack?.artUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(width * 2, height * 2)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MarqueeText {
                        Layout.fillWidth: true
                        font.pixelSize: 14
                        font.bold: true
                        color: root.textCol
                        text: MprisController.activeTrack?.title ?? ""
                    }
                    MarqueeText {
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        color: root.dimTextCol
                        text: MprisController.activeTrack?.artist ?? ""
                    }
                }
            }

            WavySeekbar {
                Layout.fillWidth: true
                implicitHeight: 14
                amplitude: 3
                progress: {
                    const p = MprisController.activePlayer
                    return (p && p.length > 0) ? Math.max(0, Math.min(1, p.position / p.length)) : 0
                }
                accentColor: SMColors.accent
                dimColor: root.dimTextCol
                animate: MprisController.isPlaying
                onSeekRequested: fraction => {
                    const p = MprisController.activePlayer
                    if (!p || p.length <= 0) return
                    p.position = fraction * p.length
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                Layout.alignment: Qt.AlignHCenter

                IconText {
                    text: "skip_previous"
                    font.pixelSize: 20
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.previous() }
                }
                IconText {
                    text: MprisController.isPlaying ? "pause" : "play_arrow"
                    font.pixelSize: 24
                    color: SMColors.accent
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.togglePlaying() }
                }
                IconText {
                    text: "skip_next"
                    font.pixelSize: 20
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: MprisController.next() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 3

                Repeater {
                    model: 28
                    delegate: Rectangle {
                        id: eqBar
                        required property int index
                        readonly property real level: root.visualizerPoints.length > 0
                            ? Math.max(0, Math.min(1, (root.visualizerPoints[Math.min(eqBar.index, root.visualizerPoints.length - 1)] ?? 0) / 1000))
                            : 0
                        Layout.alignment: Qt.AlignBottom
                        implicitWidth: 3
                        implicitHeight: 3 + level * 16
                        radius: width / 2
                        antialiasing: true
                        color: SMColors.accent
                        opacity: 0.5 + level * 0.5

                        Behavior on implicitHeight { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on opacity { NumberAnimation { duration: 90 } }
                    }
                }
            }
        }
    }
}
