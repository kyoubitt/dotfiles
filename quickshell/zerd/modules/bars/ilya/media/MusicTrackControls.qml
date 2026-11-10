import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/media"
import qs.modules.music as Orbit

ColumnLayout {
    id: controls
    required property var root
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    Layout.topMargin: -root.s(14)
    spacing: root.s(12)

    ColumnLayout {
        z: 1
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        spacing: root.s(6)
        opacity: root.introText
        transform: Translate { x: root.s(25) * (1 - root.introText) }
        
        MarqueeText {
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(25)
            text: (root.targetPlayer && root.targetPlayer.trackTitle !== "") ? root.targetPlayer.trackTitle : I18n.t("music.nothing_playing")
            color: root.dynamicTextColor
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(19)
            font.bold: true
            marqueeSpacing: root.s(50)
            speed: 25
            active: root.active

            Behavior on color { ColorAnimation { duration: 600 } }
        }

        Text {
            renderType: Text.NativeRendering
            text: root.targetPlayer && root.targetPlayer.trackArtist ? I18n.t("music.by_artist", { "artist": root.targetPlayer.trackArtist }) : I18n.t("music.by_artist", { "artist": I18n.t("music.unknown_artist") })
            color: root.dynamicTextColor
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(13.5)
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(18)
        }
        RowLayout {
            id: pillRow
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            spacing: root.s(9)
            ClickButton {
                id: devicePill
                maxTextWidth: Math.max(root.s(90), Math.floor((sourceDropdown.visible ? controls.width - pillRow.spacing - sourceDropdown.implicitWidth : controls.width * 0.55) - horizontalPadding * 2))
                Layout.preferredHeight: root.s(22)
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: root.s(10)
                buttonIcon: root.activeDeviceIcon || "󰓃"
                buttonText: root.activeDeviceName || I18n.t("music.speaker")
                iconFontSize: root.s(12)
                textFontSize: root.s(11.5)
                accentColor: ThemeBackend.surface0 || "#313244"
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.text || "#cdd6f4"
            }
            Dropdown {
                id: sourceDropdown
                visible: root.playerList.length >= 2
                Layout.preferredHeight: root.s(22)
                implicitHeight: root.s(22)
                implicitWidth: root.s(140)
                cornerRadius: ThemeBackend.borderRadius
                options: root.playerOptions
                currentIndex: root.currentPlayerIndex
                fontPixelSize: root.s(11.5)
                iconSize: root.s(12)
                accentColor: ThemeBackend.mauve || "#cba6f7"
                baseColor: Qt.alpha(ThemeBackend.surface0 || "#313244", ThemeBackend.elementOpacity)
                hoverColor: ThemeBackend.surface1 || "#45475a"
                dropdownColor: ThemeBackend.surface0
                borderColor: Qt.alpha(ThemeBackend.surface2 || "#585b70", 0.6)
                textColor: ThemeBackend.text || "#cdd6f4"
                activeTextColor: ThemeBackend.crust || "#11111b"
                onValueChanged: (index, value) => {
                    root.selectPlayerByIndex(index);
                }
            }
            ClickButton {
                id: sourcePill
                visible: root.playerList.length < 2
                maxTextWidth: Math.max(root.s(60), Math.floor(controls.width - pillRow.spacing - devicePill.implicitWidth - horizontalPadding * 2))
                Layout.preferredHeight: root.s(22)
                cornerRadius: ThemeBackend.borderRadius
                horizontalPadding: root.s(10)
                buttonText: I18n.t("music.via_source", { "source": root.targetPlayer ? (root.targetPlayer.identity || root.targetPlayer.desktopEntry || "Media") : I18n.t("music.offline") })
                textFontSize: root.s(11.5)
                accentColor: ThemeBackend.surface0 || "#313244"
                bgOpacity: ThemeBackend.elementOpacity
                textColor: ThemeBackend.subtext0 || "#9399b2"
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: -root.s(6)
        spacing: root.s(2)
        opacity: root.introControls
        transform: Translate { x: root.s(18) * (1 - root.introControls); y: root.s(9) * (1 - root.introControls) }

        WavySeekBar {
            id: progBar
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(50)
            Layout.topMargin: -root.s(16)
            Layout.bottomMargin: -root.s(2)
            Layout.alignment: Qt.AlignVCenter
            from: 0.0
            to: root.targetPlayer ? root.targetPlayer.length : 100.0
            value: root.currentLivePosition
            playing: root.targetPlayer ? root.targetPlayer.isPlaying : false
            waveColor: ThemeBackend.mauve || "#cba6f7"

            property bool seekPending: false

            Timer {
                id: seekTimer
                interval: 1000
                onTriggered: progBar.seekPending = false
            }

            Connections {
                target: root.targetPlayer
                function onPositionChanged() {
                    if (!root.active) return;
                    if (!progBar.isDragging && !progBar.seekPending && root.targetPlayer) {
                        progBar.value = root.targetPlayer.position;
                    }
                }
            }

            onMoved: val => {
                if (root.targetPlayer && root.targetPlayer.canSeek) {
                    progBar.seekPending = true;
                    seekTimer.restart();
                    progBar.value = val;
                    root.targetPlayer.position = val;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { 
                text: root.formatTime(root.currentLivePosition); 
                color: root.dynamicTextColor; 
                font.family: ThemeBackend.fontFamily; 
                font.bold: true; 
                font.pixelSize: root.s(12); 
                Behavior on color { ColorAnimation { duration: 600 } }
            }
            Item { Layout.fillWidth: true }
            Text { 
                text: root.formatTime(root.targetPlayer ? root.targetPlayer.length : 0); 
                color: root.dynamicTextColor; 
                font.family: ThemeBackend.fontFamily; 
                font.bold: true; 
                font.pixelSize: root.s(12); 
                Behavior on color { ColorAnimation { duration: 600 } }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: root.s(18)
        opacity: root.introControls
        transform: Translate { y: root.s(18) * (1 - root.introControls) }

        IconButton {
            id: prevMediaBtn
            Layout.preferredWidth: root.s(32)
            Layout.preferredHeight: root.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰒮"
            iconFontSize: root.s(11)
            accentColor: ThemeBackend.surface0 || "#313244"
            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : ThemeBackend.elementOpacity
            textColor: isHoveredOrHighlighted ? (ThemeBackend.text || "#cdd6f4") : (ThemeBackend.subtext0 || "#a6adc8")
            Layout.alignment: Qt.AlignVCenter
            onClicked: MprisController.previous()
        }

        // the play button is Orbit's: a soft-lobed cookie that turns while a song plays
        Item {
            id: playPauseBtn
            Layout.preferredWidth: root.s(50)
            Layout.preferredHeight: root.s(50)
            Layout.alignment: Qt.AlignVCenter
            readonly property bool playing: root.targetPlayer ? root.targetPlayer.isPlaying : false
            scale: playTap.pressed ? 0.92 : (playHover.hovered ? 1.05 : 1)
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
            Orbit.Cookie {
                anchors.fill: parent
                color: ThemeBackend.mauve || "#cba6f7"
                lobes: 9; amp: 0.07
                spin: playPauseBtn.playing; spinMs: 9000
            }
            Text {
                anchors.centerIn: parent
                text: playPauseBtn.playing ? "pause" : "play_arrow"
                font.family: ThemeBackend.symbolFont
                font.variableAxes: ({ "wght": 600, "opsz": 24, "FILL": 1 })
                font.pixelSize: root.s(26)
                color: ThemeBackend.crust
                renderType: Text.NativeRendering
            }
            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: playTap; onTapped: { Sounds.playSfx("reusables/iconbutton/click.wav", 0.7); MprisController.togglePlaying() } }
        }

        IconButton {
            id: nextMediaBtn
            Layout.preferredWidth: root.s(32)
            Layout.preferredHeight: root.s(32)
            cornerRadius: ThemeBackend.borderRadius
            buttonIcon: "󰒭"
            iconFontSize: root.s(11)
            accentColor: ThemeBackend.surface0 || "#313244"
            bgOpacity: ThemeBackend.liquidGlass ? 1.0 : ThemeBackend.elementOpacity
            textColor: isHoveredOrHighlighted ? (ThemeBackend.text || "#cdd6f4") : (ThemeBackend.subtext0 || "#a6adc8")
            Layout.alignment: Qt.AlignVCenter
            onClicked: MprisController.next()
        }
    }
}
