import QtQuick
import Quickshell
import qs
import qs.services

// Volume and brightness, each with a line naming what it controls.
Column {
    id: root

    property var screen: null
    readonly property var mon: Brightness.getMonitorForScreen(root.screen) ?? Brightness.monitors[0]
    spacing: 8

    Column {
        width: parent.width
        spacing: 4
        BarText { text: Audio.friendlyDeviceName(Audio.sink); font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        BarSlider {
            width: parent.width
            icon: (Audio.sink?.audio?.muted ?? false) || Audio.value <= 0 ? "volume_off" : Audio.value < 0.5 ? "volume_down" : "volume_up"
            value: (Audio.sink?.audio?.muted ?? false) ? 0 : Audio.value
            onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.muted = false; Audio.setSinkVolume(v) }
        }
    }
    Column {
        width: parent.width
        spacing: 4
        BarText { text: root.mon?.model ?? "Screen"; font.pixelSize: 11; color: BarStyle.subtext; width: parent.width; elide: Text.ElideRight }
        BarSlider {
            width: parent.width
            icon: "brightness_6"
            value: root.mon?.brightness ?? 0
            onMoved: v => root.mon?.setBrightness(Math.max(0.05, Math.min(0.99, v)))
        }
    }
}
