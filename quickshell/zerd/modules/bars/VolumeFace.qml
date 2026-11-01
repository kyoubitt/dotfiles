import QtQuick
import qs.services

// Click mutes, wheel changes the volume in 5% steps.
BarPill {
    id: root

    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    interactive: true
    onClicked: Audio.toggleMute()
    onWheel: event => Audio.setSinkVolume(Math.max(0, Math.min(1, Audio.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))

    BarIcon {
        name: root.muted || Audio.value <= 0 ? "volume_off" : Audio.value < 0.34 ? "volume_mute" : Audio.value < 0.67 ? "volume_down" : "volume_up"
        color: root.muted ? BarStyle.subtext : BarStyle.text
    }
    BarText { visible: !root.vertical; text: Math.round(Audio.value * 100) + "%" }
}
