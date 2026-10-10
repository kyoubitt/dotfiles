import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Services.Mpris
import qs.services

Item {
    id: root
    implicitWidth: controls.implicitWidth
    implicitHeight: controls.implicitHeight + 130

    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: hasPlayer && player.isPlaying
    readonly property string artUrl: hasPlayer ? (player.trackArtUrl ?? "") : ""
    readonly property string title: hasPlayer ? (player.trackTitle || "Nothing playing") : "Nothing playing"
    readonly property string artist: hasPlayer ? (player.trackArtist || "") : ""

    function formatDuration(seconds) {
        const s = Math.max(0, Math.round(seconds))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // Real source app icon (Spotify, a browser, etc.), not just a generic
    // note glyph - desktopEntry is the MPRIS-reported .desktop id (e.g.
    // "spotify", "firefox"), fed through the same AppSearch icon-theme
    // lookup the dock's own app icons use. Empty fallback ("", not
    // AppSearch's usual "image-missing" default) so an unresolved source
    // comes back empty instead of a broken-image glyph - the plain
    // "graphic_eq" Text below is the fallback for that case instead.
    readonly property string sourceIconPath: hasPlayer
        ? AppSearch.getIconSource(player.desktopEntry ?? "", "")
        : ""

    // Declared here (a direct child of root), not nested inside the
    // RowLayout that uses it - inline `component` blocks must be direct
    // children of the file's root object.
    component TransportGlyph: Text {
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        color: WallustTheme.textPrimary
    }

    // MPRIS position doesn't update reactively on its own while playing.
    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: root.player.positionChanged()
    }

        // The art ring takes all the height above the controls and sizes
        // itself to the largest circle that fits, instead of a fixed
        // 76px puck floating in empty space.
        Item {
            id: artArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: controls.top
            anchors.bottomMargin: 10

            // Whole-pixel size and position - centerIn can land on a half
            // pixel, which made the art and text around it look soft.
            Item {
                id: ring
                width: Math.round(Math.min(artArea.width, artArea.height))
                height: width
                x: Math.round((artArea.width - width) / 2)
                y: Math.round((artArea.height - height) / 2)

                WCavaVisualizer {
                    anchors.fill: parent
                    barColor: WallustTheme.accent
                    innerRadius: ring.width * 0.36
                    maxBarLength: ring.width * 0.07
                }

                Item {
                    id: spinner
                    width: Math.round(ring.width * 0.68)
                    height: width
                    x: Math.round((ring.width - width) / 2)
                    y: Math.round((ring.height - height) / 2)

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 8000
                        loops: Animation.Infinite
                        running: root.isPlaying
                    }

                    Rectangle {
                        id: circleMaskShape
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }
                    Image {
                        id: circleArt
                        anchors.fill: parent
                        visible: false
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(width * 3, height * 3)
                    }
                    // Masked output rendered into a 3x texture, then downsampled -
                    // a 1:1 layer texture made the masked art look soft.
                    // Same supersampling the dock's DockAppIcon uses.
                    GE.OpacityMask {
                        anchors.fill: parent
                        source: circleArt
                        maskSource: circleMaskShape
                        visible: root.artUrl !== ""
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 3, height * 3)
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        antialiasing: true
                        color: WallustTheme.bgCard
                        visible: root.artUrl === ""
                    }
                }

                // Click the art to play or pause.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }
        }

    // Controls pinned to the bottom edge, so their y-positions are whole
    // pixels (a fill-height art area above them left them at fractional
    // offsets, which is what made their text look soft).
    ColumnLayout {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10


        // Seek bar - plain track + fill + click/drag to seek, a hover
        // marker previewing where a click would land, and elapsed/
        // remaining time underneath (there was no time readout at all
        // before - just the bare bar with nothing to say how far into
        // the track that fill actually was).
        Item {
            id: seekBar
            Layout.fillWidth: true
            implicitHeight: 10

            readonly property real fraction: (root.hasPlayer && root.player.length > 0)
                ? Math.max(0, Math.min(1, root.player.position / root.player.length))
                : 0
            readonly property bool seekable: root.hasPlayer && root.player.length > 0
            readonly property real hoverFraction: seekMouse.containsMouse
                ? Math.max(0, Math.min(1, seekMouse.mouseX / width))
                : -1

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                antialiasing: true
                color: WallustTheme.bgCard
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * seekBar.fraction
                height: 4
                radius: 2
                antialiasing: true
                color: WallustTheme.accent
            }
            // Preview marker - shows where a click would seek to, without
            // committing anything until the actual click.
            Rectangle {
                visible: seekBar.seekable && seekBar.hoverFraction >= 0
                x: seekBar.width * seekBar.hoverFraction - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 12
                radius: 1
                antialiasing: true
                color: WallustTheme.textPrimary
                opacity: 0.6
            }
            MouseArea {
                id: seekMouse
                anchors.fill: parent
                enabled: seekBar.seekable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    const frac = Math.max(0, Math.min(1, mouse.x / width))
                    root.player.position = frac * root.player.length
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.hasPlayer ? root.formatDuration(root.player.position) : "0:00"
                color: WallustTheme.textSecondary
                font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: seekBar.seekable
                text: seekBar.seekable ? "-" + root.formatDuration(root.player.length - root.player.position) : ""
                color: WallustTheme.textSecondary
                font.pixelSize: 10
            }
        }

        // Transport controls.
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            TransportGlyph {
                text: "shuffle"
                color: root.hasPlayer && root.player.shuffle ? WallustTheme.accent : WallustTheme.textSecondary
                opacity: root.hasPlayer && root.player.shuffleSupported ? 1 : 0.35
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.shuffleSupported
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.shuffle = !root.player.shuffle
                }
            }
            TransportGlyph {
                text: "skip_previous"
                opacity: root.hasPlayer && root.player.canGoPrevious ? 1 : 0.35
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.previous()
                }
            }
            TransportGlyph {
                text: root.isPlaying ? "pause_circle" : "play_circle"
                font.pixelSize: 30
                color: WallustTheme.accent
                opacity: root.hasPlayer && root.player.canTogglePlaying ? 1 : 0.35
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }
            TransportGlyph {
                text: "skip_next"
                opacity: root.hasPlayer && root.player.canGoNext ? 1 : 0.35
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.canGoNext
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.next()
                }
            }
            TransportGlyph {
                readonly property bool looping: root.hasPlayer && root.player.loopState !== MprisLoopState.None
                text: looping ? "repeat_on" : "repeat"
                color: looping ? WallustTheme.accent : WallustTheme.textSecondary
                opacity: root.hasPlayer && root.player.loopSupported ? 1 : 0.35
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasPlayer && root.player.loopSupported
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const cur = root.player.loopState
                        root.player.loopState = cur === MprisLoopState.None ? MprisLoopState.Playlist
                            : cur === MprisLoopState.Playlist ? MprisLoopState.Track
                            : MprisLoopState.None
                    }
                }
            }
        }

        // Bottom metadata bar - source glyph + title/artist.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Source icon in a proper circular backplate - same ring
            // treatment DockAppIcon uses in the side dock - instead of a
            // bare small glyph plus a separate app-name label. The icon
            // alone reads clearly at this size; the name text next to it
            // was redundant and made the whole row feel cramped.
            Item {
                implicitWidth: 30
                implicitHeight: 30

                // Plain image, no mask or offscreen layer - the layered
                // OpacityMask path was the one piece of this card that
                // consistently rendered soft.
                Image {
                    id: sourceIcon
                    anchors.fill: parent
                    source: root.sourceIconPath
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    sourceSize: Qt.size(width * 3, height * 3)
                }
                Text {
                    anchors.fill: parent
                    visible: sourceIcon.status !== Image.Ready
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "graphic_eq"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 15
                    color: WallustTheme.textSecondary
                }
            }

            // Plain title + artist, truncated with an ellipsis. This used
            // to be a scrolling marquee, which could leave the name
            // invisible for long stretches of its animation cycle.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: WallustTheme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.artist !== ""
                    text: root.artist
                    color: WallustTheme.textSecondary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }
}
