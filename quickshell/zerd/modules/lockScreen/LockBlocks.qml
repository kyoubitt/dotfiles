import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.startMenu

// Glass blocks under the clock: what is playing, the battery, the weather. Display only, nothing to press.
Item {
    id: root

    readonly property bool hasMedia: NowPlaying.player !== null
    readonly property bool hasBattery: Battery.available
    readonly property bool hasWeather: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
    readonly property real blockH: 84

    implicitWidth: row.implicitWidth
    implicitHeight: (hasMedia || hasBattery || hasWeather) ? blockH : 0
    visible: implicitHeight > 0

    component Block: Rectangle {
        height: root.blockH
        radius: 28
        antialiasing: true
        color: ColorUtils.applyAlpha("#000000", 0.4)
        border.width: 1
        border.color: ColorUtils.applyAlpha(SMColors.fg, 0.16)
    }

    Row {
        id: row
        spacing: 12
        anchors.horizontalCenter: parent.horizontalCenter

        // ---- now playing
        Block {
            visible: root.hasMedia
            width: 320
            readonly property real progress: (NowPlaying.player && NowPlaying.player.length > 0)
                ? Math.max(0, Math.min(1, NowPlaying.player.position / NowPlaying.player.length)) : 0
            Timer {
                interval: 1000; repeat: true; running: root.visible && root.hasMedia && NowPlaying.isPlaying
                onTriggered: { if (NowPlaying.player) NowPlaying.player.positionChanged() }
            }
            Item {
                id: cover
                x: 14; y: 14; width: 56; height: 56
                Rectangle { anchors.fill: parent; radius: 18; color: ColorUtils.applyAlpha(SMColors.accent, 0.2)
                    LockIcon { anchors.centerIn: parent; text: "music_note"; fill: 1; iconSize: 24; color: SMColors.accent } }
                Image { id: art; anchors.fill: parent; visible: false; asynchronous: true; fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(112, 112); source: NowPlaying.activeTrack?.artUrl ?? "" }
                Rectangle { id: artMask; anchors.fill: parent; radius: 18; visible: false; layer.enabled: true }
                MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: artMask }
            }
            Column {
                x: 82; y: 16; width: parent.width - 82 - 18
                spacing: 2
                LockText { width: parent.width; elide: Text.ElideRight; text: NowPlaying.activeTrack?.title ?? ""; font.pixelSize: 15; font.weight: Font.Medium }
                LockText { width: parent.width; elide: Text.ElideRight; text: NowPlaying.activeTrack?.artist ?? ""; opacity: 0.65; font.pixelSize: 13 }
            }
            // thin progress line along the bottom
            Rectangle {
                x: 82; y: parent.height - 16; width: parent.width - 82 - 18; height: 4; radius: 2
                color: ColorUtils.applyAlpha(SMColors.fg, 0.16)
                Rectangle { width: parent.width * parent.parent.progress; height: parent.height; radius: 2; color: SMColors.accent
                    Behavior on width { NumberAnimation { duration: 900 } } }
            }
        }

        // ---- battery
        Block {
            visible: root.hasBattery
            width: 148
            LockIcon {
                x: 18; anchors.verticalCenter: parent.verticalCenter
                text: Battery.isCharging ? "battery_charging_full" : (Battery.percentage > 0.8 ? "battery_full" : Battery.percentage > 0.4 ? "battery_5_bar" : "battery_2_bar")
                fill: 1; iconSize: 30
                color: Battery.isLow && !Battery.isCharging ? Appearance.colors.colError : SMColors.accent
            }
            Column {
                x: 62; anchors.verticalCenter: parent.verticalCenter
                LockText { text: Math.round(Battery.percentage * 100) + "%"; font.pixelSize: 24; font.weight: Font.Medium }
                LockText { text: Battery.isCharging ? "charging" : (Battery.isPluggedIn ? "plugged in" : "on battery"); opacity: 0.65; font.pixelSize: 12 }
            }
        }

        // ---- weather
        Block {
            visible: root.hasWeather
            width: 176
            LockIcon {
                x: 18; anchors.verticalCenter: parent.verticalCenter
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                fill: 1; iconSize: 32; color: SMColors.accent
            }
            Column {
                x: 64; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64 - 14
                LockText { text: String(Weather.data?.temp ?? ""); font.pixelSize: 24; font.weight: Font.Medium }
                LockText { width: parent.width; elide: Text.ElideRight; text: String(Weather.data?.city ?? ""); opacity: 0.65; font.pixelSize: 12 }
            }
        }
    }
}
