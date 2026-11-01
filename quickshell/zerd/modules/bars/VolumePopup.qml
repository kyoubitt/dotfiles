import QtQuick
import Quickshell.Services.Pipewire
import qs.services

// Output volume, mute, output device and per-app levels.
Column {
    id: root

    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    spacing: 12

    // App streams must be bound before their volume can be read or set.
    PwObjectTracker { objects: Audio.outputAppNodes }

    BarSlider {
        width: 300
        icon: root.muted || Audio.value <= 0 ? "volume_off" : Audio.value < 0.5 ? "volume_down" : "volume_up"
        value: root.muted ? 0 : Audio.value
        onMoved: v => { if (Audio.sink?.audio) Audio.sink.audio.muted = false; Audio.setSinkVolume(v) }
    }

    Row {
        spacing: 8
        component Chip: Rectangle {
            id: chip
            property string icon
            property string text
            property bool on: false
            signal tapped()
            height: 32; width: chipRow.implicitWidth + 24; radius: 16
            color: on ? BarStyle.accent : BarStyle.plateHover
            Behavior on color { ColorAnimation { duration: 110 } }
            Row {
                id: chipRow; anchors.centerIn: parent; spacing: 6
                BarIcon { name: chip.icon; size: 16; color: chip.on ? BarStyle.onAccent : BarStyle.text }
                BarText { text: chip.text; font.pixelSize: 12; color: chip.on ? BarStyle.onAccent : BarStyle.text }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.tapped() }
        }
        Chip { icon: root.muted ? "volume_off" : "volume_up"; text: root.muted ? "Muted" : "Mute"; on: root.muted; onTapped: Audio.toggleMute() }
        Chip { icon: "mic_off"; text: "Mic"; on: Audio.source?.audio?.muted ?? false; onTapped: Audio.toggleMicMute() }
    }

    Column {
        visible: Audio.outputDevices.length > 1
        width: 300
        spacing: 2
        BarText { text: "Output"; font.pixelSize: 11; color: BarStyle.subtext }
        Repeater {
            model: Audio.outputDevices
            delegate: Item {
                required property var modelData
                readonly property bool current: modelData === Audio.sink
                width: 300; height: 32
                Rectangle { anchors.fill: parent; radius: 10; color: dev.containsMouse ? BarStyle.plateHover : "transparent" }
                BarIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: current ? "radio_button_checked" : "radio_button_unchecked"; size: 16; color: current ? BarStyle.accent : BarStyle.subtext }
                BarText { x: 34; width: 256; anchors.verticalCenter: parent.verticalCenter; text: Audio.friendlyDeviceName(modelData); elide: Text.ElideRight; font.pixelSize: 12 }
                MouseArea { id: dev; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.setDefaultSink(modelData) }
            }
        }
    }

    Column {
        visible: Audio.outputAppNodes.length > 0
        width: 300
        spacing: 6
        BarText { text: "Apps"; font.pixelSize: 11; color: BarStyle.subtext }
        Repeater {
            model: Audio.outputAppNodes.slice(0, 4)
            delegate: Row {
                required property var modelData
                spacing: 10
                BarText { width: 90; anchors.verticalCenter: parent.verticalCenter; text: Audio.appNodeDisplayName(modelData); elide: Text.ElideRight; font.pixelSize: 12 }
                BarSlider {
                    width: 200; trackHeight: 22
                    value: modelData.audio?.volume ?? 0
                    onMoved: v => { if (modelData.audio) modelData.audio.volume = v }
                }
            }
        }
    }
}
