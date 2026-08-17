pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.startMenu

Item {
    id: root

    property var screen: null

    Component.onCompleted: ResourceUsage.ensureRunning()

    function formatBytesPerSec(bytes) {
        if (bytes >= 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB/s"
        return Math.round(bytes) + " B/s"
    }

    // Blurred wallpaper strip, cropped from the *absolute* top-left of the
    // screen (0,0 to screenW,height) - same idea as the dock's bgLayer,
    // which crops starting at (0, thickness) i.e. exactly where this crop
    // ends. Same crop math, adjacent regions, so the blurred result is
    // visually continuous across the seam instead of two independently
    // blurred patches that never quite agree in color.
    Item {
        id: bgLayer
        anchors.fill: parent

        readonly property real screenW: root.screen?.width ?? bgLayer.width
        readonly property real screenH: root.screen?.height ?? bgLayer.height

        Image {
            id: wallpaperCrop
            visible: false
            source: Wallpapers.effectiveWallpaperUrl
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            width: bgLayer.screenW
            height: bgLayer.screenH
            sourceSize.width: width
            sourceSize.height: height
        }

        Item {
            anchors.fill: parent
            visible: Wallpapers.effectiveWallpaperUrl !== "" && wallpaperCrop.status === Image.Ready

            ShaderEffectSource {
                id: blurSource
                sourceItem: wallpaperCrop
                sourceRect: Qt.rect(0, 0, bgLayer.width, bgLayer.height)
                textureSize: Qt.size(bgLayer.width, bgLayer.height)
                hideSource: true
                live: true
                smooth: true
            }

            MultiEffect {
                anchors.fill: parent
                source: blurSource
                saturation: 0.12
                blurEnabled: true
                blurMax: 64
                blur: 1
            }
        }

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha("#000000", 0.3)
        }
    }

    component StatText: Text {
        color: ColorUtils.applyAlpha(SMColors.fg, 0.85)
        font.pixelSize: 12
        // Matches the desktop clock's font - was defaulting to Qt's
        // generic fallback instead of the system font, an inconsistency
        // between the two most visible bits of text in the shell.
        font.family: "Maple Mono NF CN"
        // Medium instead of the default Regular weight - at 12px Regular
        // read as too thin/washed-out next to the bolder icons beside it.
        font.weight: Font.Medium
        // Was missing entirely - same grainy-text cause as the desktop
        // clock had before NativeRendering got added there.
        renderType: Text.NativeRendering
    }

    component Stat: Row {
        spacing: 4
        Layout.alignment: Qt.AlignVCenter
    }

    // Thin separator between stat groups - without it the icon+number pairs
    // ran together into one unbroken row with no way to tell where one
    // stat ends and the next begins.
    component StatDivider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 14
        color: ColorUtils.applyAlpha(SMColors.fg, 0.15)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        // Now playing, left-aligned - marquees only when the title/artist
        // don't fit in the reserved width.
        RowLayout {
            Layout.preferredWidth: 220
            spacing: 6
            visible: MprisController.activePlayer !== null

            Item {
                // Plain sibling click target instead of nesting the
                // MouseArea inside MaterialSymbol - that wasn't actually
                // toggling playback (verified the service itself works via
                // `qs ipc call mpris playPause`, so the click just wasn't
                // reaching it).
                implicitWidth: 24
                implicitHeight: 24

                // Same hover-circle language as the dock's icons - this was
                // the only clickable control in the bar with no hover
                // feedback at all.
                Rectangle {
                    anchors.centerIn: parent
                    width: playMouse.containsMouse ? 26 : 20
                    height: width
                    radius: height / 2
                    antialiasing: true
                    color: playMouse.containsMouse ? ColorUtils.applyAlpha(SMColors.fg, 0.12) : "transparent"
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: MprisController.isPlaying ? "pause" : "play_arrow"
                    iconSize: 13
                    color: SMColors.accent
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MprisController.togglePlaying()
                }
            }
            MarqueeText {
                Layout.fillWidth: true
                Layout.preferredWidth: 200
                text: {
                    const artist = MprisController.activePlayer?.trackArtist ?? ""
                    const title = MprisController.activePlayer?.trackTitle ?? ""
                    return artist ? `${artist} - ${title}` : title
                }
                color: ColorUtils.applyAlpha(SMColors.fg, 0.85)
                font.pixelSize: 12
                font.family: "Maple Mono NF CN"
                font.weight: Font.Medium
            }
        }

        Item { Layout.fillWidth: true }

        // System stats, right-aligned - trimmed to the essentials (dropped
        // GPU%, weather, date, and the verbose RAM "· X GB" suffix).
        Stat {
            MaterialSymbol { text: "speed"; iconSize: 13; color: SMColors.fg }
            StatText { text: Math.round(ResourceUsage.cpuUsage * 100) + "%" }
        }
        StatDivider {}
        Stat {
            MaterialSymbol { text: "memory"; iconSize: 13; color: SMColors.fg }
            StatText { text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" }
        }
        StatDivider {}
        Stat {
            MaterialSymbol { text: "swap_vert"; iconSize: 13; color: SMColors.fg }
            StatText {
                text: root.formatBytesPerSec(ResourceUsage.netDownBytesPerSec) + " / " + root.formatBytesPerSec(ResourceUsage.netUpBytesPerSec)
            }
        }
        StatDivider {}
        Stat {
            MaterialSymbol {
                text: "thermostat"
                iconSize: 13
                color: ResourceUsage.maxTemp >= ResourceUsage.tempWarningThreshold ? "#E57373" : SMColors.fg
            }
            StatText { text: ResourceUsage.cpuTemp + "°C" }
        }
        StatDivider {}
        Stat {
            MaterialSymbol { text: "schedule"; iconSize: 13; color: SMColors.accent }
            StatText { text: DateTime.time; color: ColorUtils.applyAlpha(SMColors.accent, 0.9) }
        }
    }
}
