import QtQuick
import Quickshell
import qs
import qs.services

// Volume and brightness together on one card, each with a line naming what it controls and its level.
BarCard {
    id: root

    property var screen: null
    readonly property var mon: Brightness.getMonitorForScreen(root.screen) ?? Brightness.monitors[0]
    readonly property real volume: (Audio.sink?.audio?.muted ?? false) ? 0 : Audio.value
    pad: 14

    Column {
        width: parent.width
        spacing: 10

        Column {
            width: parent.width
            spacing: 2
            Item {
                width: parent.width; height: 16
                BarText { width: parent.width - 44; elide: Text.ElideRight; text: Audio.friendlyDeviceName(Audio.sink); font.pixelSize: 11; color: BarStyle.subtext }
                BarText { anchors.right: parent.right; text: Math.round(root.volume * 100) + "%"; font.pixelSize: 11; font.weight: Font.DemiBold; color: BarStyle.subtext }
            }
            QuickSlider {
                width: parent.width
                icon: (Audio.sink?.audio?.muted ?? false) || Audio.value <= 0 ? "volume_off" : Audio.value < 0.5 ? "volume_down" : "volume_up"
                value: root.volume
                onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.muted = false; Audio.setSinkVolume(v) }
            }
        }
        Column {
            width: parent.width
            spacing: 2
            Item {
                width: parent.width; height: 16
                BarText { width: parent.width - 44; elide: Text.ElideRight; text: root.mon?.model ?? "Screen"; font.pixelSize: 11; color: BarStyle.subtext }
                BarText { anchors.right: parent.right; text: Math.round((root.mon?.brightness ?? 0) * 100) + "%"; font.pixelSize: 11; font.weight: Font.DemiBold; color: BarStyle.subtext }
            }
            QuickSlider {
                width: parent.width
                icon: "brightness_6"
                value: root.mon?.brightness ?? 0
                onMoved: v => root.mon?.setBrightness(Math.max(0.05, Math.min(0.99, v)))
            }
        }
    }
}
