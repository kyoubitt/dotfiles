pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.iris.style

// Quick controls next to a dock, as on the old side dock: brightness and
// volume rings (click cycles presets, wheel steps, right click on volume
// mutes), do-not-disturb, Wi-Fi and Bluetooth. `controls` picks which show
// and in what order.
Row {
    id: root

    property var screen: null
    property int size: 36
    property var controls: ["brightness", "volume", "dnd"]
    spacing: 8

    readonly property var brightnessPresets: [0.05, 0.10, 0.15, 0.25, 0.50, 0.75, 0.99]
    readonly property var volumePresets: [0, 0.25, 0.50, 0.75, 1.0]
    function nextPreset(presets, current) { return presets.find(p => p > current + 0.02) ?? presets[0] }

    readonly property var monitor: Brightness.getMonitorForScreen(root.screen) ?? Brightness.monitors[0] ?? null

    component Ring: Item {
        id: ring
        property string icon
        property real value: 0
        property bool lit: false
        signal clicked(var mouse)
        signal wheel(var event)
        width: root.size
        height: root.size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            color: ring.lit ? IrisStyle.accent : (area.containsMouse ? IrisStyle.fillHover : IrisStyle.bodySurface)
            border.width: 1
            border.color: IrisStyle.hairline
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        // Value ring, drawn as an arc.
        Canvas {
            anchors.fill: parent
            visible: !ring.lit && ring.value > 0
            property real v: ring.value
            property color col: IrisStyle.accent
            onVChanged: requestPaint()
            onColChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset()
                c.lineWidth = 2; c.lineCap = "round"; c.strokeStyle = col
                c.beginPath()
                c.arc(width / 2, height / 2, width / 2 - 3, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.02, Math.min(1, v)))
                c.stroke()
            }
        }
        Text {
            anchors.centerIn: parent
            text: ring.icon
            color: ring.lit ? IrisStyle.inkOnAccent : IrisStyle.text
            renderType: Text.QtRendering
            font.family: Appearance.font.family.iconMaterial
            font.pixelSize: 18
            font.hintingPreference: Font.PreferNoHinting
            font.variableAxes: ({ "FILL": ring.lit ? 1 : 0, "opsz": 18 })
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => ring.clicked(mouse)
            onWheel: wheel => ring.wheel(wheel)
        }
    }

    Repeater {
        model: root.controls
        delegate: Loader {
            id: slot
            required property string modelData
            sourceComponent: ({
                brightness: brightness, volume: volume, dnd: dnd, wifi: wifi, bluetooth: bluetooth
            })[modelData] ?? null
        }
    }

    Component {
        id: brightness
        Ring {
            icon: "brightness_6"
            value: root.monitor?.brightness ?? 0
            onClicked: if (root.monitor) root.monitor.setBrightness(root.nextPreset(root.brightnessPresets, root.monitor.brightness))
            onWheel: event => event.angleDelta.y > 0 ? Brightness.increaseBrightness() : Brightness.decreaseBrightness()
        }
    }
    Component {
        id: volume
        Ring {
            readonly property bool muted: Audio.sink?.audio?.muted ?? false
            icon: muted || Audio.value <= 0 ? "volume_off" : "volume_up"
            value: muted ? 0 : Math.min(1, Audio.value)
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) { Audio.toggleMute(); return }
                if (muted) Audio.sink.audio.muted = false
                Audio.setSinkVolume(root.nextPreset(root.volumePresets, Audio.value))
            }
            onWheel: event => event.angleDelta.y > 0 ? Audio.incrementVolume() : Audio.decrementVolume()
        }
    }
    Component {
        id: dnd
        Ring {
            icon: Notifications.silent ? "notifications_off" : "notifications"
            lit: Notifications.silent
            onClicked: Notifications.toggleSilent()
        }
    }
    Component {
        id: wifi
        Ring {
            icon: Network.materialSymbol
            lit: false
            onClicked: Network.toggleWifi()
        }
    }
    Component {
        id: bluetooth
        Ring {
            visible: BluetoothStatus.available
            icon: !BluetoothStatus.enabled ? "bluetooth_disabled" : BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
            lit: BluetoothStatus.connected
            onClicked: { const a = Bluetooth.defaultAdapter; if (a) a.enabled = !a.enabled }
        }
    }
}
